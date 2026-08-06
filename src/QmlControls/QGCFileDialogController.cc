#include "QGCFileDialogController.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"
#include "AppSettings.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QProcess>
#include <QtCore/QStandardPaths>
#include <QtCore/QUrl>

QGC_LOGGING_CATEGORY(QGCFileDialogControllerLog, "QMLControls.QGCFileDialogController")

namespace {
QString normalizeResourcePath(const QString &path)
{
    if (path.startsWith(QStringLiteral("qrc:/"))) {
        return QStringLiteral(":/") + path.mid(5);
    }
    if (path.startsWith(QStringLiteral("qrc:"))) {
        return path.mid(3);
    }
    return path;
}
} // namespace

QGCFileDialogController::QGCFileDialogController(QObject *parent)
    : QObject(parent)
{
    qCDebug(QGCFileDialogControllerLog) << this;
}

QGCFileDialogController::~QGCFileDialogController()
{
    qCDebug(QGCFileDialogControllerLog) << this;
}

QStringList QGCFileDialogController::getFiles(const QString &directoryPath, const QStringList &nameFilters)
{
    qCDebug(QGCFileDialogControllerLog) << "getFiles" << directoryPath << nameFilters;

    QDir fileDir(directoryPath);
    const QFileInfoList fileInfoList = fileDir.entryInfoList(nameFilters,  QDir::Files, QDir::Name);

    QStringList files;
    for (const QFileInfo &fileInfo: fileInfoList) {
        qCDebug(QGCFileDialogControllerLog) << "getFiles found" << fileInfo.fileName();
        files << fileInfo.fileName();
    }

    return files;
}

bool QGCFileDialogController::fileExists(const QString &filename)
{
    const QString path = normalizeResourcePath(filename);
    return QFile::exists(path);
}

bool QGCFileDialogController::copyFile(const QString &sourcePath, const QString &destPath)
{
    if (sourcePath.isEmpty() || destPath.isEmpty()) {
        return false;
    }

    const QString source = normalizeResourcePath(sourcePath);
    QFile::remove(destPath);

    const QFileInfo destInfo(destPath);
    QDir().mkpath(destInfo.absolutePath());

    if (!QFile::copy(source, destPath)) {
        qCWarning(QGCFileDialogControllerLog) << "copyFile failed" << source << "->" << destPath;
        return false;
    }

    // Copied files from qrc are read-only by default; clear that for downloads.
    QFile::setPermissions(destPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser | QFileDevice::ReadGroup | QFileDevice::ReadOther);
    return true;
}

QString QGCFileDialogController::resolveUserManualPdfPath()
{
    const QString fileName = QStringLiteral("Agriculture drone.pdf");
    const QStringList candidates = {
        QCoreApplication::applicationDirPath() + QStringLiteral("/UserManual/") + fileName,
        QCoreApplication::applicationDirPath() + QStringLiteral("/../UserManual/") + fileName,
        QCoreApplication::applicationDirPath() + QStringLiteral("/../../UserManual/") + fileName,
        QDir::currentPath() + QStringLiteral("/UserManual/") + fileName,
        QStringLiteral("/home/shreeon-technologies/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE/UserManual/") + fileName,
    };

    for (const QString &candidate : candidates) {
        const QFileInfo info(candidate);
        if (info.exists() && info.isFile()) {
            return info.absoluteFilePath();
        }
    }

    const QString resourcePath = QStringLiteral(":/UserManual/AgricultureDrone.pdf");
    if (QFile::exists(resourcePath)) {
        return QStringLiteral("qrc:/UserManual/AgricultureDrone.pdf");
    }

    return QString();
}

QStringList QGCFileDialogController::renderPdfPages(const QString &pdfPath, int dpi)
{
    QStringList pageUrls;
    if (pdfPath.isEmpty()) {
        return pageUrls;
    }

    const QString cacheRoot = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/UserManualPreview");
    QDir cacheDir(cacheRoot);
    if (cacheDir.exists()) {
        const QStringList oldFiles = cacheDir.entryList(QDir::Files);
        for (const QString &oldFile : oldFiles) {
            cacheDir.remove(oldFile);
        }
    } else {
        QDir().mkpath(cacheRoot);
    }

    QString localPdfPath = normalizeResourcePath(pdfPath);
    QString tempPdfPath;

    if (localPdfPath.startsWith(QStringLiteral(":/"))) {
        tempPdfPath = cacheRoot + QStringLiteral("/manual.pdf");
        QFile::remove(tempPdfPath);
        if (!QFile::copy(localPdfPath, tempPdfPath)) {
            qCWarning(QGCFileDialogControllerLog) << "Failed to extract PDF from resources" << localPdfPath;
            return pageUrls;
        }
        QFile::setPermissions(tempPdfPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser);
        localPdfPath = tempPdfPath;
    }

    if (!QFile::exists(localPdfPath)) {
        qCWarning(QGCFileDialogControllerLog) << "PDF not found" << localPdfPath;
        return pageUrls;
    }

    const QString outputPrefix = cacheRoot + QStringLiteral("/page");
    QProcess process;
    process.start(QStringLiteral("pdftoppm"), {
        QStringLiteral("-png"),
        QStringLiteral("-r"),
        QString::number(qMax(72, dpi)),
        localPdfPath,
        outputPrefix
    });

    if (!process.waitForFinished(120000) || process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        qCWarning(QGCFileDialogControllerLog) << "pdftoppm failed"
                                              << process.errorString()
                                              << process.readAllStandardError();
        return pageUrls;
    }

    const QStringList pages = cacheDir.entryList({ QStringLiteral("page*.png") }, QDir::Files, QDir::Name);
    for (const QString &page : pages) {
        pageUrls << QUrl::fromLocalFile(cacheDir.absoluteFilePath(page)).toString();
    }

    return pageUrls;
}

QString QGCFileDialogController::fullyQualifiedFilename(const QString& directoryPath, const QString& filename, const QStringList& nameFilters)
{
    QString firstFileExtention;

    // Check that the filename has one of the specified file extensions

    bool extensionFound = true;
    if (nameFilters.count()) {
        extensionFound = false;
        for (const QString& nameFilter: nameFilters) {
            if (nameFilter.startsWith("*.")) {
                const QString fileExtension = nameFilter.right(nameFilter.length() - 2);
                if (fileExtension != "*") {
                    if (firstFileExtention.isEmpty()) {
                        firstFileExtention = fileExtension;
                    }
                    if (filename.endsWith(fileExtension)) {
                        extensionFound = true;
                        break;
                    }
                }
            } else if (nameFilter != "*") {
                qCWarning(QGCFileDialogControllerLog) << "unsupported name filter format" << nameFilter;
            }
        }
    }

    // Add the extension if it is missing
    QString filenameWithExtension = filename;
    if (!extensionFound) {
        filenameWithExtension = QStringLiteral("%1.%2").arg(filename).arg(firstFileExtention);
    }

    return (directoryPath + QStringLiteral("/") + filenameWithExtension);
}

void QGCFileDialogController::deleteFile(const QString &filename)
{
    QFile::remove(filename);
}

QString QGCFileDialogController::fullFolderPathToShortMobilePath(const QString &fullFolderPath)
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    const QString defaultSavePath = SettingsManager::instance()->appSettings()->savePath()->rawValueString();
    if (fullFolderPath.startsWith(defaultSavePath)) {
        const int lastDirSepIndex = fullFolderPath.lastIndexOf(QStringLiteral("/"));
        return (QCoreApplication::applicationName() + QStringLiteral("/") + fullFolderPath.right(fullFolderPath.length() - lastDirSepIndex));
    }
#else
    qCWarning(QGCFileDialogControllerLog) << Q_FUNC_INFO << "should only be used in mobile builds";
#endif
    return fullFolderPath;
}

QString QGCFileDialogController::urlToLocalFile(QUrl url)
{
    // For some strange reason on Qt6 running on Linux files returned by FileDialog are not returned as local file urls.
    // Seems to be new behavior with Qt6.
    if (url.isLocalFile()) {
        return url.toLocalFile();
    }

    return url.toString();
}
