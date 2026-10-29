#include "QGCFileDialogController.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"
#include "AppSettings.h"

#include <QtConcurrent/QtConcurrentRun>
#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QMetaObject>
#include <QtCore/QPointer>
#include <QtCore/QProcess>
#include <QtCore/QStandardPaths>
#include <QtCore/QUrl>
#include <QtCore/QVariantMap>
#include <QtPositioning/QGeoCoordinate>

QGC_LOGGING_CATEGORY(QGCFileDialogControllerLog, "QMLControls.QGCFileDialogController")

namespace {
struct PlanPreviewBounds {
    bool valid = false;
    double north = 0.0;
    double south = 0.0;
    double east = 0.0;
    double west = 0.0;

    void addCoordinate(const QGeoCoordinate &coordinate)
    {
        if (!valid) {
            north = south = coordinate.latitude();
            east = west = coordinate.longitude();
            valid = true;
            return;
        }

        north = qMax(north, coordinate.latitude());
        south = qMin(south, coordinate.latitude());
        east = qMax(east, coordinate.longitude());
        west = qMin(west, coordinate.longitude());
    }
};

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

bool coordinateFromJsonArray(const QJsonArray &coordinateArray, QGeoCoordinate &coordinate)
{
    if (coordinateArray.size() < 2 || !coordinateArray[0].isDouble() || !coordinateArray[1].isDouble()) {
        return false;
    }

    const double latitude = coordinateArray[0].toDouble();
    const double longitude = coordinateArray[1].toDouble();
    if (qFuzzyIsNull(latitude) && qFuzzyIsNull(longitude)) {
        return false;
    }

    coordinate = QGeoCoordinate(latitude, longitude);
    return coordinate.isValid();
}

bool appendJsonCoordinate(const QJsonArray &coordinateArray, QVariantList &path, PlanPreviewBounds &bounds, QGeoCoordinate *appendedCoordinate = nullptr)
{
    QGeoCoordinate coordinate;
    if (!coordinateFromJsonArray(coordinateArray, coordinate)) {
        return false;
    }

    path.append(QVariant::fromValue(coordinate));
    bounds.addCoordinate(coordinate);
    if (appendedCoordinate) {
        *appendedCoordinate = coordinate;
    }
    return true;
}

void appendJsonCoordinatePath(const QJsonArray &coordinateArray, QVariantList &path, PlanPreviewBounds &bounds)
{
    for (const QJsonValue &coordinateValue : coordinateArray) {
        if (coordinateValue.isArray()) {
            appendJsonCoordinate(coordinateValue.toArray(), path, bounds);
        }
    }
}

QVariantMap planPreviewMetadata(const QString &filePath)
{
    QVariantMap preview;
    preview.insert(QStringLiteral("hasPreview"), false);
    preview.insert(QStringLiteral("takeoffValid"), false);
    preview.insert(QStringLiteral("routePath"), QVariantList());
    preview.insert(QStringLiteral("boundaryPath"), QVariantList());
    preview.insert(QStringLiteral("takeoffCoordinate"), QVariant::fromValue(QGeoCoordinate()));
    preview.insert(QStringLiteral("startCoordinate"), QVariant::fromValue(QGeoCoordinate()));
    preview.insert(QStringLiteral("endCoordinate"), QVariant::fromValue(QGeoCoordinate()));
    preview.insert(QStringLiteral("north"), 0.0);
    preview.insert(QStringLiteral("south"), 0.0);
    preview.insert(QStringLiteral("east"), 0.0);
    preview.insert(QStringLiteral("west"), 0.0);
    preview.insert(QStringLiteral("missionMode"), QString());
    preview.insert(QStringLiteral("missionModeInferred"), false);

    QFile planFile(filePath);
    if (!planFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return preview;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(planFile.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        return preview;
    }

    const QJsonObject planObject = document.object();
    const QJsonArray missionItems = planObject
                                          .value(QStringLiteral("mission"))
                                          .toObject()
                                          .value(QStringLiteral("items"))
                                          .toArray();
    QVariantList routePath;
    QVariantList boundaryPath;
    PlanPreviewBounds bounds;
    QGeoCoordinate takeoffCoordinate;
    bool hasSurveyItem = false;

    for (const QJsonValue &itemValue : missionItems) {
        if (!itemValue.isObject()) {
            continue;
        }

        const QJsonObject item = itemValue.toObject();
        const QString itemType = item.value(QStringLiteral("type")).toString();
        if (itemType == QStringLiteral("SimpleItem")) {
            const QJsonArray parameters = item.value(QStringLiteral("params")).toArray();
            if (parameters.size() <= 5 || !parameters[4].isDouble() || !parameters[5].isDouble()) {
                continue;
            }

            const QJsonArray coordinateArray{ parameters[4], parameters[5] };
            QGeoCoordinate appendedCoordinate;
            if (appendJsonCoordinate(coordinateArray, routePath, bounds, &appendedCoordinate)) {
                const int command = item.value(QStringLiteral("command")).toInt();
                // MAV_CMD_NAV_TAKEOFF and MAV_CMD_NAV_VTOL_TAKEOFF.
                if (!takeoffCoordinate.isValid() && (command == 22 || command == 84)) {
                    takeoffCoordinate = appendedCoordinate;
                }
            }
            continue;
        }

        if (itemType != QStringLiteral("ComplexItem")) {
            continue;
        }

        if (item.value(QStringLiteral("complexItemType")).toString() == QStringLiteral("survey")) {
            hasSurveyItem = true;
        }

        const QJsonArray polygon = item.value(QStringLiteral("polygon")).toArray();
        if (boundaryPath.isEmpty() && !polygon.isEmpty()) {
            appendJsonCoordinatePath(polygon, boundaryPath, bounds);
        }

        const QJsonObject transectStyle = item.value(QStringLiteral("TransectStyleComplexItem")).toObject();
        const QJsonArray visualTransectPoints = transectStyle.value(QStringLiteral("VisualTransectPoints")).toArray();
        if (!visualTransectPoints.isEmpty()) {
            appendJsonCoordinatePath(visualTransectPoints, routePath, bounds);
            continue;
        }

        // Older plans do not persist generated transects. Their source shape
        // still provides a useful preview until the plan is loaded and rebuilt.
        const QJsonArray polyline = item.value(QStringLiteral("polyline")).toArray();
        if (!polyline.isEmpty()) {
            appendJsonCoordinatePath(polyline, routePath, bounds);
        } else if (!polygon.isEmpty()) {
            appendJsonCoordinatePath(polygon, routePath, bounds);
        }
    }

    if (routePath.isEmpty() && !boundaryPath.isEmpty()) {
        routePath = boundaryPath;
    }

    QString missionMode = planObject.value(QStringLiteral("missionMode")).toString();
    const bool supportedMissionMode = missionMode == QStringLiteral("routeMapping")
            || missionMode == QStringLiteral("agricultureSpraying")
            || missionMode == QStringLiteral("seedSpreader")
            || missionMode == QStringLiteral("customMission");
    const bool missionModeInferred = !supportedMissionMode;
    if (missionModeInferred) {
        // Old plan files predate mission-mode metadata. Survey plans are safest
        // to restore as Route Mapping; all other plans use Custom Mission.
        missionMode = hasSurveyItem ? QStringLiteral("routeMapping") : QStringLiteral("customMission");
    }

    preview.insert(QStringLiteral("routePath"), routePath);
    preview.insert(QStringLiteral("boundaryPath"), boundaryPath);
    preview.insert(QStringLiteral("hasPreview"), bounds.valid && !routePath.isEmpty());
    preview.insert(QStringLiteral("takeoffValid"), takeoffCoordinate.isValid());
    preview.insert(QStringLiteral("takeoffCoordinate"), QVariant::fromValue(takeoffCoordinate));
    preview.insert(QStringLiteral("missionMode"), missionMode);
    preview.insert(QStringLiteral("missionModeInferred"), missionModeInferred);

    if (bounds.valid) {
        preview.insert(QStringLiteral("north"), bounds.north);
        preview.insert(QStringLiteral("south"), bounds.south);
        preview.insert(QStringLiteral("east"), bounds.east);
        preview.insert(QStringLiteral("west"), bounds.west);
        preview.insert(QStringLiteral("startCoordinate"), routePath.first());
        preview.insert(QStringLiteral("endCoordinate"), routePath.last());
    }

    return preview;
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

QVariantList QGCFileDialogController::getPlanFileInfoList(const QString &directoryPath, const QStringList &nameFilters)
{
    qCDebug(QGCFileDialogControllerLog) << "getPlanFileInfoList" << directoryPath << nameFilters;

    QDir fileDir(directoryPath);
    const QFileInfoList fileInfoList = fileDir.entryInfoList(nameFilters, QDir::Files, QDir::Time);

    QVariantList files;
    files.reserve(fileInfoList.size());
    for (const QFileInfo &fileInfo : fileInfoList) {
        QVariantMap metadata;
        metadata.insert(QStringLiteral("fileName"), fileInfo.fileName());
        metadata.insert(QStringLiteral("baseName"), fileInfo.completeBaseName());
        metadata.insert(QStringLiteral("filePath"), fileInfo.absoluteFilePath());
        metadata.insert(QStringLiteral("size"), fileInfo.size());
        metadata.insert(QStringLiteral("lastModified"), fileInfo.lastModified());
        const QVariantMap preview = planPreviewMetadata(fileInfo.absoluteFilePath());
        for (auto it = preview.constBegin(); it != preview.constEnd(); ++it) {
            metadata.insert(it.key(), it.value());
        }
        files.append(metadata);
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
    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        appDir + QStringLiteral("/UserManual/") + fileName,
        appDir + QStringLiteral("/../UserManual/") + fileName,
        appDir + QStringLiteral("/../../UserManual/") + fileName,
        // Source-tree relative path when running from a build directory.
        appDir + QStringLiteral("/../../../UserManual/") + fileName,
        QDir::currentPath() + QStringLiteral("/UserManual/") + fileName,
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

namespace {

QString findPdftoppmExecutable()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList bundledCandidates = {
        appDir + QStringLiteral("/pdftoppm"),
        appDir + QStringLiteral("/../libexec/pdftoppm"),
    };
    for (const QString &candidate : bundledCandidates) {
        const QFileInfo info(candidate);
        if (info.exists() && info.isFile() && info.isExecutable()) {
            return info.absoluteFilePath();
        }
    }
    return QStandardPaths::findExecutable(QStringLiteral("pdftoppm"));
}

/// Worker-thread PDF → PNG conversion. Safe to call off the GUI thread.
QStringList renderPdfPagesWorker(const QString &pdfPath, int dpi, QString *errorMessageOut)
{
    QStringList pageUrls;
    if (errorMessageOut) {
        errorMessageOut->clear();
    }
    if (pdfPath.isEmpty()) {
        if (errorMessageOut) {
            *errorMessageOut = QObject::tr("PDF path is empty.");
        }
        return pageUrls;
    }

    const QString cacheRoot =
        QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
        + QStringLiteral("/UserManualPreview");
    QDir cacheDir(cacheRoot);
    if (cacheDir.exists()) {
        const QStringList oldFiles = cacheDir.entryList(QDir::Files);
        for (const QString &oldFile : oldFiles) {
            cacheDir.remove(oldFile);
        }
    } else if (!QDir().mkpath(cacheRoot)) {
        if (errorMessageOut) {
            *errorMessageOut = QObject::tr("Could not create PDF preview cache.");
        }
        return pageUrls;
    }

    QString localPdfPath = normalizeResourcePath(pdfPath);
    if (localPdfPath.startsWith(QStringLiteral(":/"))) {
        const QString tempPdfPath = cacheRoot + QStringLiteral("/manual.pdf");
        QFile::remove(tempPdfPath);
        if (!QFile::copy(localPdfPath, tempPdfPath)) {
            qCWarning(QGCFileDialogControllerLog) << "Failed to extract PDF from resources" << localPdfPath;
            if (errorMessageOut) {
                *errorMessageOut = QObject::tr("Failed to extract the bundled user manual PDF.");
            }
            return pageUrls;
        }
        QFile::setPermissions(
            tempPdfPath,
            QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser);
        localPdfPath = tempPdfPath;
    }

    if (!QFile::exists(localPdfPath)) {
        qCWarning(QGCFileDialogControllerLog) << "PDF not found" << localPdfPath;
        if (errorMessageOut) {
            *errorMessageOut = QObject::tr("User manual PDF not found.");
        }
        return pageUrls;
    }

    const QString pdftoppm = findPdftoppmExecutable();
    if (pdftoppm.isEmpty()) {
        qCWarning(QGCFileDialogControllerLog) << "pdftoppm not found";
        if (errorMessageOut) {
            *errorMessageOut = QObject::tr(
                "Unable to render PDF. Install poppler-utils (pdftoppm) or use an AppImage that bundles it.");
        }
        return pageUrls;
    }

    const QString outputPrefix = cacheRoot + QStringLiteral("/page");
    QProcess process;
    process.setProgram(pdftoppm);
    process.setArguments({
        QStringLiteral("-png"),
        QStringLiteral("-r"),
        QString::number(qMax(72, dpi)),
        localPdfPath,
        outputPrefix,
    });
    process.start();
    if (!process.waitForStarted(15000)) {
        qCWarning(QGCFileDialogControllerLog) << "pdftoppm failed to start" << process.errorString();
        if (errorMessageOut) {
            *errorMessageOut = QObject::tr("Failed to start pdftoppm: %1").arg(process.errorString());
        }
        return pageUrls;
    }

    // Conversion can take a while for large manuals; this runs off the GUI thread.
    if (!process.waitForFinished(180000)
        || process.exitStatus() != QProcess::NormalExit
        || process.exitCode() != 0) {
        const QString stderrText = QString::fromLocal8Bit(process.readAllStandardError());
        qCWarning(QGCFileDialogControllerLog) << "pdftoppm failed"
                                              << process.errorString()
                                              << stderrText;
        if (errorMessageOut) {
            *errorMessageOut = QObject::tr("PDF rendering failed.");
        }
        return pageUrls;
    }

    const QStringList pages = cacheDir.entryList({QStringLiteral("page*.png")}, QDir::Files, QDir::Name);
    for (const QString &page : pages) {
        pageUrls << QUrl::fromLocalFile(cacheDir.absoluteFilePath(page)).toString();
    }
    if (pageUrls.isEmpty() && errorMessageOut) {
        *errorMessageOut = QObject::tr("PDF rendering produced no pages.");
    }
    return pageUrls;
}

} // namespace

void QGCFileDialogController::renderPdfPagesAsync(const QString &pdfPath, int dpi)
{
    const int generation = ++_pdfRenderGeneration;
    const QPointer<QGCFileDialogController> self(this);
    (void)QtConcurrent::run([self, generation, pdfPath, dpi]() {
        QString errorMessage;
        const QStringList pages = renderPdfPagesWorker(pdfPath, dpi, &errorMessage);
        if (!self) {
            return;
        }
        QMetaObject::invokeMethod(
            self.data(),
            [self, generation, pages, errorMessage]() {
                if (!self || generation != self->_pdfRenderGeneration) {
                    return;
                }
                emit self->pdfPagesRendered(pages, errorMessage);
            },
            Qt::QueuedConnection);
    });
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
