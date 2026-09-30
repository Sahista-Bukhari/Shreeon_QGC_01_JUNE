#include "QGCZip.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QSaveFile>
#include <QtCore/private/qzipreader_p.h>
#include <QtCore/private/qzipwriter_p.h>

QGC_LOGGING_CATEGORY(QGCZipLog, "Utilities.QGCZip")

namespace QGCZip {

bool zipDirectory(const QString &directoryPath, const QString &zipFilePath)
{
    QDir dir(directoryPath);
    if (!dir.exists()) {
        qCDebug(QGCZipLog) << "Directory does not exist:" << directoryPath;
        return false;
    }

    QFile zipFile(zipFilePath);
    if (!zipFile.open(QIODevice::WriteOnly)) {
        qCDebug(QGCZipLog) << "Could not open zip file for writing:" << zipFilePath;
        return false;
    }

    QZipWriter zipWriter(&zipFile);
    zipWriter.setCompressionPolicy(QZipWriter::AutoCompress);

    QStringList fileList = dir.entryList(QDir::Files | QDir::NoDotAndDotDot | QDir::AllDirs, QDir::DirsFirst);

    for (const QString &fileName : fileList) {
        QString filePath = directoryPath + "/" + fileName;

        if (QFileInfo(filePath).isDir()) {
            zipWriter.addDirectory(fileName);
        } else {
            QFile file(filePath);
            if (file.open(QIODevice::ReadOnly)) {
                zipWriter.addFile(fileName, file.readAll());
                file.close();
            } else {
                qCDebug(QGCZipLog) << "Could not open file for reading:" << filePath;
                return false;
            }
        }
    }

    zipWriter.close();
    return true;
}

bool unzipFile(const QString &zipFilePath, const QString &outputDirectoryPath)
{
    QDir outputDir(outputDirectoryPath);
    if (!outputDir.exists()) {
        if (!outputDir.mkpath(outputDirectoryPath)) {
            qCDebug(QGCZipLog) << "Failed to create output directory:" << outputDirectoryPath;
            return false;
        }
    }

    QFile zipFile(zipFilePath);
    if (!zipFile.open(QIODevice::ReadOnly)) {
        qCDebug(QGCZipLog) << "Could not open zip file:" << zipFilePath;
        return false;
    }

    QZipReader zipReader(&zipFile);
    if (!zipReader.isReadable()) {
        qCDebug(QGCZipLog) << "Could not read zip file:" << zipFilePath;
        return false;
    }

    const QList<QZipReader::FileInfo> allFiles = zipReader.fileInfoList();

    for (const QZipReader::FileInfo &fileInfo : allFiles) {
        QString filePath = outputDirectoryPath + "/" + fileInfo.filePath;

        if (fileInfo.isDir) {
            QDir().mkpath(filePath);
        } else if (fileInfo.isFile) {
            QFile outFile(filePath);
            if (outFile.open(QIODevice::WriteOnly)) {
                outFile.write(zipReader.fileData(fileInfo.filePath));
                outFile.close();
            } else {
                qDebug() << "Could not open file for writing:" << filePath;
                return false;
            }
        }
    }

    zipReader.close();
    return true;
}

bool extractFile(const QString &zipFilePath, const QString &memberPath, const QString &outputFilePath)
{
    QFile zipFile(zipFilePath);
    if (!zipFile.open(QIODevice::ReadOnly)) {
        qCWarning(QGCZipLog) << "Could not open ZIP file:" << zipFilePath;
        return false;
    }

    QZipReader zipReader(&zipFile);
    if (!zipReader.isReadable()) {
        qCWarning(QGCZipLog) << "Could not read ZIP file:" << zipFilePath;
        return false;
    }

    bool memberFound = false;
    const QList<QZipReader::FileInfo> entries = zipReader.fileInfoList();
    for (const QZipReader::FileInfo &entry : entries) {
        if (entry.isFile && entry.filePath == memberPath) {
            memberFound = true;
            break;
        }
    }
    if (!memberFound) {
        qCWarning(QGCZipLog) << "ZIP member was not found:" << memberPath;
        return false;
    }

    const QFileInfo outputInfo(outputFilePath);
    if (!QDir().mkpath(outputInfo.absolutePath())) {
        qCWarning(QGCZipLog) << "Could not create output directory:" << outputInfo.absolutePath();
        return false;
    }

    const QByteArray contents = zipReader.fileData(memberPath);
    QSaveFile outputFile(outputFilePath);
    if (!outputFile.open(QIODevice::WriteOnly)
        || outputFile.write(contents) != contents.size()
        || !outputFile.commit()) {
        qCWarning(QGCZipLog) << "Could not extract ZIP member to:" << outputFilePath;
        return false;
    }

    return true;
}

} // namespace QGCZip
