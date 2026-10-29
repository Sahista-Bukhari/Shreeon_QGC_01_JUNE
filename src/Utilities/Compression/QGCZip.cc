#include "QGCZip.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDir>
#include <QtCore/QElapsedTimer>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QProcess>
#include <QtCore/QSaveFile>
#include <QtCore/QStandardPaths>
#include <QtCore/private/qzipreader_p.h>

#include <cstring>
#include <limits>

QGC_LOGGING_CATEGORY(QGCZipLog, "Utilities.QGCZip")

namespace QGCZip {

namespace {

constexpr qint64 kZipTailSearchMax = 65535 + 22; // max ZIP comment + EOCD
constexpr qint64 kExtractChunkSize = 1024 * 1024;
/// Avoid QZipReader::fileData for large members (loads entire entry into RAM).
constexpr qint64 kMaxInMemoryExtractBytes = 16 * 1024 * 1024;
constexpr int kUnzipIdleTimeoutMs = 120000;
constexpr int kUnzipOverallTimeoutMs = 30 * 60 * 1000;

/// Reject absolute paths, drive letters, NUL bytes, and any .. traversal.
bool isSafeRelativeZipEntry(const QString &entryPath)
{
    if (entryPath.isEmpty() || entryPath.contains(QChar(u'\0'))) {
        return false;
    }

    const QString normalized = QDir::fromNativeSeparators(entryPath);
    if (normalized.startsWith(QLatin1Char('/'))
        || normalized.startsWith(QLatin1String("//"))
        || (normalized.size() >= 3
            && normalized.at(1) == QLatin1Char(':')
            && (normalized.at(2) == QLatin1Char('/') || normalized.at(2) == QLatin1Char('\\')))) {
        return false;
    }

    const QStringList parts = normalized.split(QLatin1Char('/'), Qt::SkipEmptyParts);
    for (const QString &part : parts) {
        if (part == QLatin1String("..")) {
            return false;
        }
    }
    return true;
}

/// Resolve entryPath under outputDirectoryPath and require the result stays inside it.
bool resolveContainedExtractPath(
    const QString &outputDirectoryPath, const QString &entryPath, QString *safePathOut)
{
    if (!safePathOut || !isSafeRelativeZipEntry(entryPath)) {
        return false;
    }

    const QString root = QDir::cleanPath(QFileInfo(outputDirectoryPath).absoluteFilePath());
    if (root.isEmpty()) {
        return false;
    }

    const QString relative = QDir::cleanPath(QDir::fromNativeSeparators(entryPath));
    if (relative == QLatin1String(".") || relative.isEmpty()) {
        *safePathOut = root;
        return true;
    }
    if (relative == QLatin1String("..") || relative.startsWith(QLatin1String("../"))) {
        return false;
    }

    const QString candidate = QDir::cleanPath(root + QLatin1Char('/') + relative);
    const QString rootPrefix = root.endsWith(QLatin1Char('/')) ? root : root + QLatin1Char('/');
    if (candidate != root && !candidate.startsWith(rootPrefix)) {
        return false;
    }

    *safePathOut = candidate;
    return true;
}

bool openExtractOutput(const QString &outputFilePath, QSaveFile *outputFile)
{
    if (!outputFile) {
        return false;
    }

    const QFileInfo outputInfo(outputFilePath);
    if (!QDir().mkpath(outputInfo.absolutePath())) {
        qCWarning(QGCZipLog) << "Could not create output directory:" << outputInfo.absolutePath();
        return false;
    }

    outputFile->setFileName(outputFilePath);
    if (!outputFile->open(QIODevice::WriteOnly)) {
        qCWarning(QGCZipLog) << "Could not open extract output:" << outputFilePath;
        return false;
    }
    return true;
}

quint16 readU16LE(const char *data)
{
    return quint16(quint8(data[0])) | (quint16(quint8(data[1])) << 8);
}

quint32 readU32LE(const char *data)
{
    return quint32(quint8(data[0]))
           | (quint32(quint8(data[1])) << 8)
           | (quint32(quint8(data[2])) << 16)
           | (quint32(quint8(data[3])) << 24);
}

quint64 readU64LE(const char *data)
{
    return quint64(readU32LE(data)) | (quint64(readU32LE(data + 4)) << 32);
}

bool findZipEocd(QFile &zipFile, qint64 *eocdOffsetOut)
{
    if (!eocdOffsetOut) {
        return false;
    }
    const qint64 fileSize = zipFile.size();
    if (fileSize < 22) {
        return false;
    }

    const qint64 searchLen = qMin(fileSize, kZipTailSearchMax);
    if (!zipFile.seek(fileSize - searchLen)) {
        return false;
    }
    const QByteArray tail = zipFile.read(searchLen);
    if (tail.size() != searchLen) {
        return false;
    }

    for (int i = int(tail.size()) - 22; i >= 0; --i) {
        if (std::memcmp(tail.constData() + i, "PK\x05\x06", 4) == 0) {
            *eocdOffsetOut = (fileSize - searchLen) + i;
            return true;
        }
    }
    return false;
}

bool readZip64CentralDirectoryStart(
    QFile &zipFile, qint64 eocdOffset, qint64 *cdOffsetOut, quint64 *entryCountOut)
{
    if (!cdOffsetOut || !entryCountOut || eocdOffset < 20) {
        return false;
    }

    // ZIP64 end-of-central-directory locator sits immediately before the EOCD.
    if (!zipFile.seek(eocdOffset - 20)) {
        return false;
    }
    char locator[20];
    if (zipFile.read(locator, 20) != 20 || std::memcmp(locator, "PK\x06\x07", 4) != 0) {
        return false;
    }

    const quint64 zip64EocdOffset = readU64LE(locator + 8);
    if (!zipFile.seek(qint64(zip64EocdOffset))) {
        return false;
    }
    char zip64Eocd[56];
    if (zipFile.read(zip64Eocd, 56) != 56 || std::memcmp(zip64Eocd, "PK\x06\x06", 4) != 0) {
        return false;
    }

    *entryCountOut = readU64LE(zip64Eocd + 32);
    *cdOffsetOut = qint64(readU64LE(zip64Eocd + 48));
    return *cdOffsetOut >= 0;
}

void applyZip64ExtraField(
    const char *extra, quint16 extraLen,
    quint64 *uncompressedSize, quint64 *compressedSize, quint64 *localOffset)
{
    if (!extra || !uncompressedSize || !compressedSize || !localOffset) {
        return;
    }

    int pos = 0;
    while (pos + 4 <= int(extraLen)) {
        const quint16 headerId = readU16LE(extra + pos);
        const quint16 dataSize = readU16LE(extra + pos + 2);
        pos += 4;
        if (pos + dataSize > int(extraLen)) {
            return;
        }
        if (headerId == 0x0001) {
            int fieldPos = 0;
            auto takeU64 = [&](quint64 *dest) {
                if (*dest == 0xFFFFFFFFu && fieldPos + 8 <= int(dataSize)) {
                    *dest = readU64LE(extra + pos + fieldPos);
                    fieldPos += 8;
                }
            };
            takeU64(uncompressedSize);
            takeU64(compressedSize);
            takeU64(localOffset);
            return;
        }
        pos += dataSize;
    }
}

bool copyFileRangeToSaveFile(QFile &zipFile, qint64 payloadOffset, qint64 byteCount, QSaveFile *out)
{
    if (!out || byteCount < 0 || !zipFile.seek(payloadOffset)) {
        return false;
    }

    QByteArray buffer;
    buffer.resize(int(qMin(byteCount, kExtractChunkSize)));
    qint64 remaining = byteCount;
    while (remaining > 0) {
        const qint64 toRead = qMin(remaining, qint64(buffer.size()));
        const qint64 n = zipFile.read(buffer.data(), toRead);
        if (n <= 0) {
            return false;
        }
        if (out->write(buffer.constData(), n) != n) {
            return false;
        }
        remaining -= n;
    }
    return true;
}

/// NodeODM often writes a nonstandard "version needed to extract" (e.g. 778).
/// Qt's QZipReader refuses those members. Stream the STORED payload to disk with
/// 64-bit sizes (including ZIP64 extra fields) without loading the archive into RAM.
bool extractStoredZipMemberToFile(
    const QString &zipFilePath, const QString &memberPath, QSaveFile *out, qint64 *bytesWrittenOut)
{
    if (!out || !bytesWrittenOut) {
        return false;
    }
    *bytesWrittenOut = 0;

    QFile zipFile(zipFilePath);
    if (!zipFile.open(QIODevice::ReadOnly)) {
        return false;
    }

    qint64 eocdOffset = -1;
    if (!findZipEocd(zipFile, &eocdOffset)) {
        return false;
    }

    char eocd[22];
    if (!zipFile.seek(eocdOffset) || zipFile.read(eocd, 22) != 22) {
        return false;
    }

    quint64 entryCount = readU16LE(eocd + 10);
    qint64 cdOffset = qint64(readU32LE(eocd + 16));
    if (entryCount == 0xFFFFu || quint32(cdOffset) == 0xFFFFFFFFu) {
        if (!readZip64CentralDirectoryStart(zipFile, eocdOffset, &cdOffset, &entryCount)) {
            return false;
        }
    }

    if (!zipFile.seek(cdOffset)) {
        return false;
    }

    for (quint64 entry = 0; entry < entryCount; ++entry) {
        char header[46];
        if (zipFile.read(header, 46) != 46 || std::memcmp(header, "PK\x01\x02", 4) != 0) {
            return false;
        }

        const quint16 method = readU16LE(header + 10);
        quint64 compressedSize = readU32LE(header + 20);
        quint64 uncompressedSize = readU32LE(header + 24);
        const quint16 nameLen = readU16LE(header + 28);
        const quint16 extraLen = readU16LE(header + 30);
        const quint16 commentLen = readU16LE(header + 32);
        quint64 localOffset = readU32LE(header + 42);

        QByteArray nameBytes = zipFile.read(nameLen);
        QByteArray extraBytes = zipFile.read(extraLen);
        if (nameBytes.size() != nameLen || extraBytes.size() != extraLen) {
            return false;
        }
        if (commentLen > 0 && zipFile.skip(commentLen) != commentLen) {
            return false;
        }

        applyZip64ExtraField(
            extraBytes.constData(), extraLen, &uncompressedSize, &compressedSize, &localOffset);

        const QString entryName = QString::fromUtf8(nameBytes);
        if (entryName != memberPath) {
            continue;
        }
        if (method != 0) {
            // Stored-only fallback. Deflated NodeODM archives still need unzip.
            return false;
        }
        if (compressedSize != uncompressedSize || uncompressedSize > quint64(std::numeric_limits<qint64>::max())) {
            return false;
        }

        char localHeader[30];
        if (!zipFile.seek(qint64(localOffset))
            || zipFile.read(localHeader, 30) != 30
            || std::memcmp(localHeader, "PK\x03\x04", 4) != 0) {
            return false;
        }
        const quint16 localNameLen = readU16LE(localHeader + 26);
        const quint16 localExtraLen = readU16LE(localHeader + 28);
        const qint64 payloadOffset =
            qint64(localOffset) + 30 + qint64(localNameLen) + qint64(localExtraLen);
        if (payloadOffset < 0
            || payloadOffset + qint64(compressedSize) > zipFile.size()) {
            return false;
        }

        if (!copyFileRangeToSaveFile(zipFile, payloadOffset, qint64(uncompressedSize), out)) {
            return false;
        }
        *bytesWrittenOut = qint64(uncompressedSize);
        return *bytesWrittenOut > 0;
    }
    return false;
}

/// Stream `unzip -p` stdout into out while the process runs (avoids pipe deadlock).
bool extractZipMemberWithUnzipToFile(
    const QString &zipFilePath, const QString &memberPath, QSaveFile *out, qint64 *bytesWrittenOut)
{
    if (!out || !bytesWrittenOut) {
        return false;
    }
    *bytesWrittenOut = 0;

    const QString unzip = QStandardPaths::findExecutable(QStringLiteral("unzip"));
    if (unzip.isEmpty()) {
        return false;
    }

    QProcess process;
    process.setProgram(unzip);
    process.setArguments({QStringLiteral("-p"), QStringLiteral("-qq"), zipFilePath, memberPath});
    process.setProcessChannelMode(QProcess::SeparateChannels);
    process.start();
    if (!process.waitForStarted(15000)) {
        qCWarning(QGCZipLog) << "unzip failed to start for" << memberPath;
        return false;
    }

    QElapsedTimer idleTimer;
    QElapsedTimer overallTimer;
    idleTimer.start();
    overallTimer.start();
    QByteArray stderrAccum;

    auto drainStdout = [&]() -> bool {
        const QByteArray chunk = process.readAllStandardOutput();
        if (chunk.isEmpty()) {
            return true;
        }
        if (out->write(chunk) != chunk.size()) {
            return false;
        }
        *bytesWrittenOut += chunk.size();
        idleTimer.restart();
        return true;
    };

    while (process.state() != QProcess::NotRunning) {
        process.waitForReadyRead(500);
        if (!drainStdout()) {
            process.kill();
            process.waitForFinished(5000);
            qCWarning(QGCZipLog) << "Failed writing unzip stdout for" << memberPath;
            return false;
        }
        stderrAccum += process.readAllStandardError();
        if (stderrAccum.size() > 65536) {
            stderrAccum = stderrAccum.right(65536);
        }
        if (idleTimer.elapsed() > kUnzipIdleTimeoutMs
            || overallTimer.elapsed() > kUnzipOverallTimeoutMs) {
            process.kill();
            process.waitForFinished(5000);
            qCWarning(QGCZipLog) << "unzip timed out for" << memberPath
                                 << "written" << *bytesWrittenOut;
            return false;
        }
    }

    if (!drainStdout()) {
        return false;
    }
    stderrAccum += process.readAllStandardError();

    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        qCWarning(QGCZipLog) << "unzip fallback failed for" << memberPath << stderrAccum;
        return false;
    }
    return *bytesWrittenOut > 0;
}

bool extractViaQZipReaderToFile(
    const QString &zipFilePath,
    const QString &memberPath,
    QSaveFile *out,
    qint64 *expectedSizeOut,
    qint64 *bytesWrittenOut)
{
    if (!out || !expectedSizeOut || !bytesWrittenOut) {
        return false;
    }
    *expectedSizeOut = -1;
    *bytesWrittenOut = 0;

    QFile zipFile(zipFilePath);
    if (!zipFile.open(QIODevice::ReadOnly)) {
        return false;
    }

    QZipReader zipReader(&zipFile);
    if (!zipReader.isReadable()) {
        return false;
    }

    for (const QZipReader::FileInfo &entry : zipReader.fileInfoList()) {
        if (!(entry.isFile && entry.filePath == memberPath)) {
            continue;
        }
        *expectedSizeOut = entry.size;
        if (entry.size < 0 || entry.size > kMaxInMemoryExtractBytes) {
            // Prefer streaming fallbacks for large GeoTIFFs.
            return false;
        }
        const QByteArray contents = zipReader.fileData(memberPath);
        if (contents.isEmpty()
            || (*expectedSizeOut > 0 && contents.size() != *expectedSizeOut)) {
            return false;
        }
        if (out->write(contents) != contents.size()) {
            return false;
        }
        *bytesWrittenOut = contents.size();
        return true;
    }
    return false;
}

} // namespace

bool unzipFile(const QString &zipFilePath, const QString &outputDirectoryPath)
{
    QDir outputDir(outputDirectoryPath);
    if (!outputDir.exists()) {
        if (!outputDir.mkpath(outputDirectoryPath)) {
            qCWarning(QGCZipLog) << "Failed to create output directory:" << outputDirectoryPath;
            return false;
        }
    }

    QFile zipFile(zipFilePath);
    if (!zipFile.open(QIODevice::ReadOnly)) {
        qCWarning(QGCZipLog) << "Could not open zip file:" << zipFilePath;
        return false;
    }

    QZipReader zipReader(&zipFile);
    if (!zipReader.isReadable()) {
        qCWarning(QGCZipLog) << "Could not read zip file:" << zipFilePath;
        return false;
    }

    const QList<QZipReader::FileInfo> allFiles = zipReader.fileInfoList();

    for (const QZipReader::FileInfo &fileInfo : allFiles) {
        if (fileInfo.isSymLink) {
            qCWarning(QGCZipLog) << "Refusing ZIP symlink entry:" << fileInfo.filePath;
            return false;
        }

        QString safePath;
        if (!resolveContainedExtractPath(outputDirectoryPath, fileInfo.filePath, &safePath)) {
            qCWarning(QGCZipLog) << "Refusing unsafe ZIP path entry:" << fileInfo.filePath;
            return false;
        }

        if (fileInfo.isDir) {
            if (!QDir().mkpath(safePath)) {
                qCWarning(QGCZipLog) << "Could not create directory from ZIP:" << safePath;
                return false;
            }
        } else if (fileInfo.isFile) {
            const QFileInfo outInfo(safePath);
            if (!QDir().mkpath(outInfo.absolutePath())) {
                qCWarning(QGCZipLog) << "Could not create parent directory for ZIP member:" << safePath;
                return false;
            }
            const QByteArray memberData = zipReader.fileData(fileInfo.filePath);
            QSaveFile outFile(safePath);
            if (!outFile.open(QIODevice::WriteOnly)
                || outFile.write(memberData) != memberData.size()
                || !outFile.commit()) {
                qCWarning(QGCZipLog) << "Could not write extracted ZIP member:" << safePath;
                return false;
            }
        }
    }

    zipReader.close();
    return true;
}

bool extractFile(const QString &zipFilePath, const QString &memberPath, const QString &outputFilePath)
{
    if (!isSafeRelativeZipEntry(memberPath)) {
        qCWarning(QGCZipLog) << "Refusing unsafe ZIP member path:" << memberPath;
        return false;
    }

    QSaveFile outputFile;
    if (!openExtractOutput(outputFilePath, &outputFile)) {
        return false;
    }

    qint64 expectedSize = -1;
    qint64 bytesWritten = 0;

    if (extractViaQZipReaderToFile(
            zipFilePath, memberPath, &outputFile, &expectedSize, &bytesWritten)) {
        if (!outputFile.commit()) {
            qCWarning(QGCZipLog) << "Could not commit extracted ZIP member to:" << outputFilePath;
            return false;
        }
        return true;
    }

    // QZipReader can list the member and still fail when the ZIP advertises an
    // unsupported "version needed to extract" (NodeODM). Stream fallbacks instead
    // of buffering the GeoTIFF (and the whole ZIP) in RAM.
    qCWarning(QGCZipLog)
        << "QZipReader could not extract" << memberPath
        << "from" << zipFilePath
        << "- trying stored-member stream fallback";

    // Reset output for the next attempt.
    outputFile.cancelWriting();
    if (!openExtractOutput(outputFilePath, &outputFile)) {
        return false;
    }
    bytesWritten = 0;

    if (!extractStoredZipMemberToFile(zipFilePath, memberPath, &outputFile, &bytesWritten)) {
        qCWarning(QGCZipLog) << "Stored-member fallback failed; trying unzip stream";
        outputFile.cancelWriting();
        if (!openExtractOutput(outputFilePath, &outputFile)) {
            return false;
        }
        bytesWritten = 0;
        if (!extractZipMemberWithUnzipToFile(zipFilePath, memberPath, &outputFile, &bytesWritten)) {
            qCWarning(QGCZipLog) << "ZIP member could not be extracted:" << memberPath;
            outputFile.cancelWriting();
            return false;
        }
    }

    if (expectedSize > 0 && bytesWritten != expectedSize) {
        qCWarning(QGCZipLog)
            << "Extracted ZIP member size mismatch for" << memberPath
            << "got" << bytesWritten << "expected" << expectedSize;
        outputFile.cancelWriting();
        return false;
    }

    if (!outputFile.commit()) {
        qCWarning(QGCZipLog) << "Could not commit extracted ZIP member to:" << outputFilePath;
        return false;
    }
    return true;
}

} // namespace QGCZip
