#include "DecompressionTest.h"
#include "QGCLZMA.h"
#include "QGCZlib.h"
#include "QGCZip.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QTemporaryDir>
#include <QtCore/private/qzipwriter_p.h>
#include <QtTest/QTest>

void DecompressionTest::_testDecompressGzip()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString gzippedFileName = QStringLiteral(":/unittest/manifest.json.gz");
    const QString decompressedFilename = tempDir.filePath(QStringLiteral("manifest.json"));
    QVERIFY(QGCZlib::inflateGzipFile(gzippedFileName, decompressedFilename));
    QVERIFY(QFileInfo::exists(decompressedFilename));
    QVERIFY(QFileInfo(decompressedFilename).size() > 0);
}

void DecompressionTest::_testDecompressLZMA()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString lzmaFilename = QStringLiteral(":/unittest/manifest.json.xz");
    const QString decompressedFilename = tempDir.filePath(QStringLiteral("manifest.json"));
    QVERIFY(QGCLZMA::inflateLZMAFile(lzmaFilename, decompressedFilename));
    QVERIFY(QFileInfo::exists(decompressedFilename));
    QVERIFY(QFileInfo(decompressedFilename).size() > 0);
}

void DecompressionTest::_testUnzip()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString zipFilename = QStringLiteral(":/unittest/manifest.json.zip");
    const QString decompressedPath = tempDir.filePath(QStringLiteral("unzipped"));
    QVERIFY(QDir().mkpath(decompressedPath));
    QVERIFY(QGCZip::unzipFile(zipFilename, decompressedPath));
    const QString extracted = QDir(decompressedPath).filePath(QStringLiteral("manifest.json"));
    QVERIFY(QFileInfo::exists(extracted));
    QVERIFY(QFileInfo(extracted).size() > 0);
}

void DecompressionTest::_testUnzipRejectsPathTraversal()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString zipPath = tempDir.filePath(QStringLiteral("traversal.zip"));
    const QString extractRoot = tempDir.filePath(QStringLiteral("extract"));
    QVERIFY(QDir().mkpath(extractRoot));

    // QZipWriter strips a leading "../", but keeps nested traversal segments.
    {
        QFile zipFile(zipPath);
        QVERIFY(zipFile.open(QIODevice::WriteOnly));
        QZipWriter writer(&zipFile);
        writer.addFile(QStringLiteral("subdir/../../escape.txt"), QByteArrayLiteral("pwned"));
        writer.addFile(QStringLiteral("safe.txt"), QByteArrayLiteral("ok"));
        writer.close();
    }

    QVERIFY(!QGCZip::unzipFile(zipPath, extractRoot));
    QVERIFY(!QFile::exists(tempDir.filePath(QStringLiteral("escape.txt"))));
    QVERIFY(!QFile::exists(QDir(extractRoot).filePath(QStringLiteral("safe.txt"))));

    QVERIFY(!QGCZip::extractFile(
        zipPath,
        QStringLiteral("subdir/../../escape.txt"),
        tempDir.filePath(QStringLiteral("out.txt"))));
    QVERIFY(!QGCZip::extractFile(
        zipPath, QStringLiteral("/abs.txt"), tempDir.filePath(QStringLiteral("out2.txt"))));
}
