#include "RouteMappingPhotoController.h"

#include "RouteMappingPiPhotoFetcher.h"
#include "SettingsManager.h"
#include "AppSettings.h"
#include "QGCLoggingCategory.h"
#include "QGCZip.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QFileInfo>
#include <QtCore/QProcess>
#include <QtCore/QSaveFile>
#include <QtCore/QStandardPaths>
#include <QtCore/QUrlQuery>
#include <QtCore/QUuid>
#include <QtCore/QTimer>
#include <QtNetwork/QHttpMultiPart>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

#include <utility>
#include <limits>

QGC_LOGGING_CATEGORY(RouteMappingPhotoControllerLog, "FlyView.RouteMappingPhotoController")

namespace {

constexpr int kNodeOdmPollIntervalMs = 2000;
constexpr auto kOrthophotoArchivePath = "odm_orthophoto/odm_orthophoto.tif";

QUrl nodeOdmUrl(const QString &path)
{
    QString endpoint = qEnvironmentVariable("QGC_NODEODM_URL").trimmed();
    if (endpoint.isEmpty()) {
        endpoint = QStringLiteral("http://127.0.0.1:3000");
    }

    QUrl url(endpoint);
    QString basePath = url.path();
    while (basePath.endsWith(QLatin1Char('/'))) {
        basePath.chop(1);
    }
    url.setPath(basePath + path);

    const QString token = qEnvironmentVariable("QGC_NODEODM_TOKEN").trimmed();
    if (!token.isEmpty()) {
        QUrlQuery query(url);
        query.addQueryItem(QStringLiteral("token"), token);
        url.setQuery(query);
    }
    return url;
}

QString nodeOdmEndpointText()
{
    QUrl endpoint = nodeOdmUrl({});
    endpoint.setQuery(QString{});
    return endpoint.toString();
}

QString nodeOdmReplyError(QNetworkReply *reply, const QByteArray &body)
{
    const QJsonDocument document = QJsonDocument::fromJson(body);
    if (document.isObject()) {
        const QString apiError = document.object().value(QStringLiteral("error")).toString();
        if (!apiError.isEmpty()) {
            return apiError;
        }
    }

    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (reply->error() != QNetworkReply::NoError) {
        return QStringLiteral("%1 (HTTP %2)").arg(reply->errorString()).arg(httpStatus);
    }
    if (httpStatus < 200 || httpStatus >= 300) {
        return QStringLiteral("NodeODM returned HTTP %1").arg(httpStatus);
    }
    return {};
}

QHttpPart nodeOdmTextPart(const QString &name, const QByteArray &value)
{
    QHttpPart part;
    part.setHeader(
        QNetworkRequest::ContentDispositionHeader,
        QStringLiteral("form-data; name=\"%1\"").arg(name));
    part.setBody(value);
    return part;
}

} // namespace

RouteMappingPhotoController::RouteMappingPhotoController(QObject *parent)
    : QObject(parent)
    , _nodeOdmNetworkManager(new QNetworkAccessManager(this))
{
    _odmPollTimer.setInterval(kNodeOdmPollIntervalMs);
    _odmPollTimer.setSingleShot(false);
    connect(&_odmPollTimer, &QTimer::timeout, this, &RouteMappingPhotoController::_pollNodeOdmTask);
}

bool RouteMappingPhotoController::odmRunning() const
{
    return _odmState == OdmState::Connecting
           || _odmState == OdmState::Uploading
           || _odmState == OdmState::Queued
           || _odmState == OdmState::Processing
           || _odmState == OdmState::Downloading;
}

bool RouteMappingPhotoController::odmReady() const
{
    return !_sessionDirectory.isEmpty()
           && !_sessionActive
           && !_waitingForPiSession
           && !_captureUdpInFlight
           && _pendingCaptures.isEmpty()
           && _fetcher
           && _fetcher->pendingFetchCount() == 0
           && !_requestedCaptureSequences.isEmpty()
           && _geotaggedSequences.size() == _requestedCaptureSequences.size()
           && !odmRunning()
           && !_odmComplete;
}

QString RouteMappingPhotoController::reconstructionStatus() const
{
    if (odmRunning()) {
        return _nodeOdmStatusText();
    }
    if (_odmComplete) {
        return tr("Complete");
    }
    if (!_odmErrorMessage.isEmpty()) {
        return tr("Failed");
    }
    if (odmReady()) {
        return tr("Ready");
    }
    if (_requestedCaptureSequences.isEmpty()) {
        return tr("Pending");
    }
    if (!_sessionActive
        && !_waitingForPiSession
        && !_captureUdpInFlight
        && _pendingCaptures.isEmpty()
        && _fetcher
        && _fetcher->pendingFetchCount() == 0
        && _geotaggedSequences.size() < _requestedCaptureSequences.size()) {
        return tr("Incomplete %1 / %2")
            .arg(_geotaggedSequences.size())
            .arg(_requestedCaptureSequences.size());
    }
    return tr("Geotagging %1 / %2")
        .arg(_geotaggedSequences.size())
        .arg(_requestedCaptureSequences.size());
}

QString RouteMappingPhotoController::_nodeOdmStatusText() const
{
    switch (_odmState) {
    case OdmState::Connecting:
        return tr("Connecting…");
    case OdmState::Uploading:
        return tr("Uploading %1%").arg(_odmProgress);
    case OdmState::Queued:
        return _odmStateDetail.isEmpty() ? tr("Queued") : _odmStateDetail;
    case OdmState::Processing:
        return _odmStateDetail.isEmpty()
                   ? tr("Processing %1%").arg(_odmProgress)
                   : tr("%1 — %2%").arg(_odmStateDetail).arg(_odmProgress);
    case OdmState::Downloading:
        return tr("Downloading GeoTIFF %1%").arg(_odmProgress);
    case OdmState::Complete:
        return tr("Complete");
    case OdmState::Failed:
        return tr("Failed");
    case OdmState::Idle:
        break;
    }
    return {};
}

void RouteMappingPhotoController::setCaptureEnabled(bool enabled)
{
    if (_captureEnabled == enabled) {
        return;
    }
    _captureEnabled = enabled;
    if (!enabled) {
        if (!_pendingCaptures.isEmpty()) {
            qCInfo(RouteMappingPhotoControllerLog)
                << "Discarding" << _pendingCaptures.size()
                << "queued Route Mapping capture(s); trigger phase inactive";
        }
        _pendingCaptures.clear();
        _notifyPendingCaptureCountChanged();
        if (_fetcher) {
            _fetcher->haltNewCaptures();
        }
    }
    emit captureEnabledChanged();
}

void RouteMappingPhotoController::_notifyPendingCaptureCountChanged()
{
    emit pendingCaptureCountChanged();
}

void RouteMappingPhotoController::setPhotoFetcher(QObject *fetcher)
{
    if (_fetcher) {
        disconnect(_fetcher, nullptr, this, nullptr);
    }
    _fetcher = qobject_cast<RouteMappingPiPhotoFetcher *>(fetcher);
    if (_fetcher) {
        connect(
            _fetcher,
            &RouteMappingPiPhotoFetcher::piSessionBeginComplete,
            this,
            &RouteMappingPhotoController::_onPiSessionBeginComplete);
        connect(
            _fetcher,
            &RouteMappingPiPhotoFetcher::triggerCaptureFinished,
            this,
            &RouteMappingPhotoController::_onTriggerCaptureFinished);
        connect(
            _fetcher,
            &RouteMappingPiPhotoFetcher::photoFetched,
            this,
            &RouteMappingPhotoController::_onPhotoFetched);
        connect(
            _fetcher,
            &RouteMappingPiPhotoFetcher::photoFullFetched,
            this,
            &RouteMappingPhotoController::_onPhotoFetched);
        connect(
            _fetcher,
            &RouteMappingPiPhotoFetcher::pendingFetchCountChanged,
            this,
            &RouteMappingPhotoController::_onFetcherPendingCountChanged);
    }
    emit reconstructionStateChanged();
}

QString RouteMappingPhotoController::photoSaveRoot() const
{
    AppSettings *appSettings = SettingsManager::instance()->appSettings();
    QString photoRoot = appSettings->photoSavePath();
    if (!photoRoot.isEmpty()) {
        return QDir::cleanPath(photoRoot);
    }

    const QString saveRoot = appSettings->savePath()->rawValue().toString();
    if (saveRoot.isEmpty()) {
        return {};
    }
    return QDir::cleanPath(QDir(saveRoot).filePath(QStringLiteral("Photo")));
}

QString RouteMappingPhotoController::_routeMappingRoot(bool ensureExists) const
{
    const QString photoRoot = photoSaveRoot();
    if (photoRoot.isEmpty()) {
        return {};
    }

    const QString routeMappingRoot = QDir(photoRoot).filePath(QStringLiteral("RouteMapping"));
    if (ensureExists) {
        if (!QDir().mkpath(routeMappingRoot)) {
            return {};
        }
        _ensureRouteMappingReadme(routeMappingRoot, photoRoot);
    }
    return QDir::cleanPath(routeMappingRoot);
}

void RouteMappingPhotoController::_ensureRouteMappingReadme(
    const QString &routeMappingRoot, const QString &photoRoot) const
{
    const QString readmePath = QDir(routeMappingRoot).filePath(QStringLiteral("README.txt"));
    if (QFileInfo::exists(readmePath)) {
        return;
    }

    const QString saveRoot = SettingsManager::instance()->appSettings()->savePath()->rawValue().toString();
    const QString readme = QStringLiteral(
                               "Route Mapping photos (JPEG + geotag JSON) are saved here.\n"
                               "\n"
                               "Layout:\n"
                               "  %1/Mission_<UTC time>_<id>/images/image_NNNN.jpg\n"
                               "  %1/Mission_<UTC time>_<id>/image_NNNN.json\n"
                               "  %1/Mission_<UTC time>_<id>/geo.txt (ODM geolocation)\n"
                               "\n"
                               "QGC Application save root: %2\n"
                               "Photo folder: %3\n"
                               "\n"
                               "Latest mission folder path is written to latest_mission_session.txt\n"
                               "when a Route Mapping photo session starts.\n"
                               "\n"
                               "Shell examples (quote paths that contain spaces):\n"
                               "  ls \"%1\"/Mission_*\n"
                               "  find \"$HOME\" -type d -name 'Mission_*' 2>/dev/null\n"
                               "  find \"$HOME\" -type f -path '*/RouteMapping/*/image_*.json' 2>/dev/null\n")
                               .arg(routeMappingRoot, saveRoot, photoRoot);

    QFile readmeFile(readmePath);
    if (readmeFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        readmeFile.write(readme.toUtf8());
    }
}

void RouteMappingPhotoController::_removeFailedSessionDirectory(const QString &sessionPath) const
{
    if (sessionPath.isEmpty()) {
        return;
    }

    QDir sessionDir(sessionPath);
    if (!sessionDir.exists()) {
        return;
    }

    // This path is used only when Pi session startup fails, before capture can
    // begin. Remove the mission skeleton, including its empty images folder.
    if (sessionDir.removeRecursively()) {
        qCInfo(RouteMappingPhotoControllerLog)
            << "Removed empty Route Mapping mission folder after failed Pi session:" << sessionPath;
    } else {
        qCWarning(RouteMappingPhotoControllerLog)
            << "Could not remove empty Route Mapping mission folder:" << sessionPath;
    }
}

void RouteMappingPhotoController::_writeSessionLocatorFiles(const QString &sessionPath) const
{
    const QString routeMappingRoot = _routeMappingRoot(false);
    if (routeMappingRoot.isEmpty()) {
        return;
    }

    const QString latestPath = QDir(routeMappingRoot).filePath(QStringLiteral("latest_mission_session.txt"));
    QFile latestFile(latestPath);
    if (latestFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        latestFile.write(sessionPath.toUtf8());
        latestFile.write("\n");
    }

    QJsonObject manifest;
    manifest.insert(QStringLiteral("sessionDirectory"), sessionPath);
    manifest.insert(QStringLiteral("routeMappingRoot"), routeMappingRoot);
    manifest.insert(QStringLiteral("photoSaveRoot"), photoSaveRoot());
    manifest.insert(
        QStringLiteral("applicationSaveRoot"),
        SettingsManager::instance()->appSettings()->savePath()->rawValue().toString());
    manifest.insert(QStringLiteral("startedAtUtc"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    manifest.insert(QStringLiteral("imageDirectory"), QDir(sessionPath).filePath(QStringLiteral("images")));
    manifest.insert(QStringLiteral("odmGeoFile"), QDir(sessionPath).filePath(QStringLiteral("geo.txt")));

    const QString manifestPath = QDir(sessionPath).filePath(QStringLiteral("session_manifest.json"));
    QFile manifestFile(manifestPath);
    if (manifestFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        manifestFile.write(QJsonDocument(manifest).toJson(QJsonDocument::Indented));
    }
}

bool RouteMappingPhotoController::beginSession()
{
    if (odmRunning()) {
        emit gcsSessionStartFailed(tr("ODM reconstruction is still running. Wait for it to finish before starting another Route Mapping mission."));
        return false;
    }
    if (_sessionActive) {
        return true;
    }
    if (_waitingForPiSession) {
        return true;
    }

    _finishRequested = false;
    _requestedCaptureSequences.clear();
    _captureMetadata.clear();
    _geotaggedSequences.clear();
    _odmPollTimer.stop();
    _odmState = OdmState::Idle;
    _odmProgress = 0;
    _odmPollFailures = 0;
    _odmInputFiles.clear();
    _odmTaskUuid.clear();
    _odmStateDetail.clear();
    _odmDownloadPath.clear();
    _odmSessionDirectory.clear();
    _odmErrorMessage.clear();
    _orthophotoPath.clear();
    _orthophotoUrl.clear();
    _orthophotoNorthWest = {};
    _orthophotoSouthEast = {};
    _odmComplete = false;
    emit orthophotoOverlayChanged();
    const QString routeMappingRoot = _routeMappingRoot(true);
    if (routeMappingRoot.isEmpty()) {
        const QString errorMessage = tr(
            "Could not create the Route Mapping photo folder. Check Application Settings save path "
            "(photos are stored under <save path>/Photo/RouteMapping).");
        qCWarning(RouteMappingPhotoControllerLog) << errorMessage;
        emit gcsSessionStartFailed(errorMessage);
        return false;
    }
    emit routeMappingRootChanged();

    _sessionToken = QStringLiteral("%1_%2")
                        .arg(QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd_HHmmss_zzz")))
                        .arg(QUuid::createUuid().toString(QUuid::Id128));
    const QString sessionName = QStringLiteral("Mission_%1").arg(_sessionToken);
    const QString sessionPath = QDir(routeMappingRoot).filePath(sessionName);
    if (!QDir().mkpath(QDir(sessionPath).filePath(QStringLiteral("images")))) {
        const QString errorMessage = tr("Could not create Route Mapping mission folder: %1").arg(sessionPath);
        qCWarning(RouteMappingPhotoControllerLog) << errorMessage;
        emit gcsSessionStartFailed(errorMessage);
        return false;
    }

    _sessionDirectory = sessionPath;
    emit sessionDirectoryChanged();
    emit reconstructionStateChanged();

    if (!_fetcher) {
        return false;
    }

    _waitingForPiSession = true;
    emit piSessionPendingChanged();
    _fetcher->beginSessionAsync();
    qCInfo(RouteMappingPhotoControllerLog)
        << "Route Mapping GCS photo folder ready; starting Pi session for"
        << sessionPath;
    return true;
}

void RouteMappingPhotoController::_onPiSessionBeginComplete(bool success)
{
    if (!_waitingForPiSession) {
        return;
    }
    _waitingForPiSession = false;
    emit piSessionPendingChanged();

    if (!success) {
        const QString errorMessage = tr("Raspberry Pi photo session could not be started.");
        for (const PendingCapture &pending : std::as_const(_pendingCaptures)) {
            emit captureFailed(pending.sequence, errorMessage);
        }
        _pendingCaptures.clear();
        _notifyPendingCaptureCountChanged();
        _finishRequested = false;
        const QString failedSessionPath = _sessionDirectory;
        _sessionDirectory.clear();
        emit sessionDirectoryChanged();
        _removeFailedSessionDirectory(failedSessionPath);
        return;
    }

    _sessionActive = true;
    _writeSessionLocatorFiles(_sessionDirectory);
    qCInfo(RouteMappingPhotoControllerLog)
        << "Route Mapping GCS photo session active"
        << _sessionDirectory
        << "photoSaveRoot"
        << photoSaveRoot();
    emit sessionActiveChanged();
    emit reconstructionStateChanged();
    _scheduleCapturePump();
}

void RouteMappingPhotoController::endSession()
{
    // Once mission mode ends, discard commands which have not reached the Pi.
    // Draining them would take photographs at the landing/RTL location instead
    // of at their planned survey coordinates.
    const QString cancelMessage = tr("Mission ended before this capture reached the camera.");
    for (const PendingCapture &pending : std::as_const(_pendingCaptures)) {
        emit captureFailed(pending.sequence, cancelMessage);
    }
    _pendingCaptures.clear();
    _notifyPendingCaptureCountChanged();
    _finishRequested = true;
    _finishSessionIfReady();
    emit reconstructionStateChanged();
}

void RouteMappingPhotoController::cancelSession()
{
    _pendingCaptures.clear();
    _notifyPendingCaptureCountChanged();
    _requestedCaptureSequences.clear();
    _captureMetadata.clear();
    _geotaggedSequences.clear();
    _finishRequested = false;
    if (_waitingForPiSession) {
        _waitingForPiSession = false;
        emit piSessionPendingChanged();
    }
    if (_fetcher) {
        _fetcher->cancelSession();
    }
    if (_sessionActive) {
        _sessionActive = false;
        emit sessionActiveChanged();
    }
    if (!_sessionDirectory.isEmpty()) {
        _sessionDirectory.clear();
        emit sessionDirectoryChanged();
    }
    emit reconstructionStateChanged();
}

void RouteMappingPhotoController::discardSessionStorage()
{
    const QString sessionPath = _sessionDirectory;
    cancelSession();
    if (odmRunning()) {
        qCWarning(RouteMappingPhotoControllerLog)
            << "Keeping Route Mapping session while ODM is running:" << sessionPath;
        return;
    }
    if (sessionPath.isEmpty()) {
        return;
    }

    QDir sessionDir(sessionPath);
    if (!sessionDir.exists()) {
        return;
    }

    if (sessionDir.removeRecursively()) {
        qCInfo(RouteMappingPhotoControllerLog)
            << "Removed Route Mapping photo folder after plan clear:" << sessionPath;
    } else {
        qCWarning(RouteMappingPhotoControllerLog)
            << "Could not remove Route Mapping photo folder:" << sessionPath;
    }
}

QString RouteMappingPhotoController::imagePathForSequence(int sequence) const
{
    if (sequence < 1 || _sessionDirectory.isEmpty()) {
        return {};
    }
    if (!_sessionActive && !_waitingForPiSession) {
        return {};
    }
    return QDir(QDir(_sessionDirectory).filePath(QStringLiteral("images"))).filePath(
        QStringLiteral("image_%1.jpg").arg(sequence, 4, 10, QChar('0')));
}

QString RouteMappingPhotoController::metadataPathForSequence(int sequence) const
{
    if (sequence < 1 || _sessionDirectory.isEmpty()) {
        return {};
    }
    if (!_sessionActive && !_waitingForPiSession) {
        return {};
    }
    return QDir(_sessionDirectory).filePath(
        QStringLiteral("image_%1.json").arg(sequence, 4, 10, QChar('0')));
}

bool RouteMappingPhotoController::_writeMetadata(int sequence, quint32 nativeTriggerSequence, double latitude, double longitude, double altitude, double heading) const
{
    const QString metaPath = metadataPathForSequence(sequence);
    if (metaPath.isEmpty()) {
        return false;
    }

    QJsonObject object;
    object.insert(QStringLiteral("triggerIndex"), sequence);
    object.insert(QStringLiteral("nativeCameraTriggerSequence"), static_cast<qint64>(nativeTriggerSequence));
    object.insert(QStringLiteral("timestamp"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    object.insert(QStringLiteral("latitude"), latitude);
    object.insert(QStringLiteral("longitude"), longitude);
    object.insert(QStringLiteral("altitude"), altitude);
    object.insert(QStringLiteral("heading"), heading);

    QFile file(metaPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return false;
    }
    file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    return true;
}

bool RouteMappingPhotoController::_appendOdmGeotag(int sequence, const QString &localFilePath)
{
    if (_geotaggedSequences.contains(sequence)) {
        return true;
    }
    const auto metadataIt = _captureMetadata.constFind(sequence);
    if (metadataIt == _captureMetadata.cend() || _sessionDirectory.isEmpty()) {
        return false;
    }

    const QString geoPath = QDir(_sessionDirectory).filePath(QStringLiteral("geo.txt"));
    QFile geoFile(geoPath);
    const bool newFile = !geoFile.exists() || geoFile.size() == 0;
    if (!geoFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        _odmErrorMessage = tr("Could not write ODM geolocation file: %1").arg(geoPath);
        emit reconstructionStateChanged();
        emit odmError(_odmErrorMessage);
        return false;
    }
    if (newFile) {
        geoFile.write("EPSG:4326\n");
    }

    const PendingCapture &capture = metadataIt.value();
    const QString row = QStringLiteral("%1 %2 %3 %4 %5 0 0\n")
                            .arg(QFileInfo(localFilePath).fileName())
                            .arg(QString::number(capture.longitude, 'f', 9))
                            .arg(QString::number(capture.latitude, 'f', 9))
                            .arg(QString::number(capture.altitude, 'f', 3))
                            .arg(QString::number(capture.heading, 'f', 2));
    if (geoFile.write(row.toUtf8()) != row.toUtf8().size()) {
        _odmErrorMessage = tr("Could not finish writing ODM geolocation data.");
        emit reconstructionStateChanged();
        emit odmError(_odmErrorMessage);
        return false;
    }
    geoFile.close();

    _geotaggedSequences.insert(sequence);
    qCInfo(RouteMappingPhotoControllerLog)
        << "Added ODM geotag for Route Mapping image" << sequence << localFilePath;
    emit reconstructionStateChanged();
    return true;
}

void RouteMappingPhotoController::_onPhotoFetched(
    int requestId, const QString &localFilePath, bool success, const QString &errorMessage)
{
    if (success) {
        (void)_appendOdmGeotag(requestId, localFilePath);
    } else if (!errorMessage.isEmpty()) {
        qCWarning(RouteMappingPhotoControllerLog)
            << "Photo transfer failed before ODM geotagging" << requestId << errorMessage;
    }
    emit reconstructionStateChanged();
}

void RouteMappingPhotoController::_onFetcherPendingCountChanged()
{
    emit reconstructionStateChanged();
}

bool RouteMappingPhotoController::startOdm()
{
    if (!odmReady()) {
        const QString errorMessage = tr("ODM can start only after the mission has ended and every requested image has reached the GCS with geolocation data.");
        emit odmError(errorMessage);
        return false;
    }

    const QDir imageDirectory(QDir(_sessionDirectory).filePath(QStringLiteral("images")));
    const QFileInfoList imageFiles = imageDirectory.entryInfoList(
        {QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"), QStringLiteral("*.JPG"), QStringLiteral("*.JPEG")},
        QDir::Files | QDir::Readable,
        QDir::Name);
    const QString geoPath = QDir(_sessionDirectory).filePath(QStringLiteral("geo.txt"));
    if (imageFiles.isEmpty() || !QFileInfo::exists(geoPath)) {
        _failOdm(tr("The mission images or geo.txt file are missing."));
        return false;
    }

    _odmInputFiles.clear();
    for (const QFileInfo &imageFile : imageFiles) {
        _odmInputFiles.append(imageFile.absoluteFilePath());
    }
    _odmInputFiles.append(geoPath);

    _odmErrorMessage.clear();
    _odmComplete = false;
    _orthophotoPath.clear();
    _odmSessionDirectory = _sessionDirectory;
    _odmTaskUuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    _odmPollFailures = 0;
    _setOdmState(OdmState::Connecting, 0);

    QNetworkRequest request{nodeOdmUrl(QStringLiteral("/info"))};
    request.setTransferTimeout(10000);
    QNetworkReply *reply = _nodeOdmNetworkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray body = reply->readAll();
        const QString error = nodeOdmReplyError(reply, body);
        reply->deleteLater();
        if (!error.isEmpty()) {
            _failOdm(tr("Cannot connect to NodeODM at %1: %2")
                         .arg(nodeOdmEndpointText(), error));
            return;
        }

        const QJsonObject info = QJsonDocument::fromJson(body).object();
        if (info.value(QStringLiteral("engine")).toString() != QStringLiteral("odm")) {
            _failOdm(tr("The configured NodeODM service is not using the ODM engine."));
            return;
        }
        const QJsonValue maxImagesValue = info.value(QStringLiteral("maxImages"));
        if (maxImagesValue.isDouble()
            && maxImagesValue.toInt() > 0
            && _odmInputFiles.size() - 1 > maxImagesValue.toInt()) {
            _failOdm(tr("NodeODM accepts at most %1 images, but this mission contains %2.")
                         .arg(maxImagesValue.toInt())
                         .arg(_odmInputFiles.size() - 1));
            return;
        }
        _beginNodeOdmUpload();
    });

    qCInfo(RouteMappingPhotoControllerLog)
        << "Connecting to NodeODM for mission" << _odmSessionDirectory
        << "task" << _odmTaskUuid;
    return true;
}

void RouteMappingPhotoController::_beginNodeOdmUpload()
{
    auto *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    multiPart->append(nodeOdmTextPart(
        QStringLiteral("name"),
        QFileInfo(_odmSessionDirectory).fileName().toUtf8()));

    QJsonArray options;
    options.append(QJsonObject{{QStringLiteral("name"), QStringLiteral("skip-3dmodel")},
                               {QStringLiteral("value"), true}});
    options.append(QJsonObject{{QStringLiteral("name"), QStringLiteral("skip-report")},
                               {QStringLiteral("value"), true}});
    multiPart->append(nodeOdmTextPart(
        QStringLiteral("options"),
        QJsonDocument(options).toJson(QJsonDocument::Compact)));

    const QJsonArray outputs{QString::fromLatin1(kOrthophotoArchivePath)};
    multiPart->append(nodeOdmTextPart(
        QStringLiteral("outputs"),
        QJsonDocument(outputs).toJson(QJsonDocument::Compact)));
    multiPart->append(nodeOdmTextPart(QStringLiteral("skipPostProcessing"), QByteArrayLiteral("true")));

    for (const QString &inputPath : std::as_const(_odmInputFiles)) {
        auto *file = new QFile(inputPath, multiPart);
        if (!file->open(QIODevice::ReadOnly)) {
            const QString error = file->errorString();
            delete multiPart;
            _failOdm(tr("Could not open NodeODM input %1: %2").arg(inputPath, error));
            return;
        }

        QHttpPart filePart;
        filePart.setHeader(
            QNetworkRequest::ContentTypeHeader,
            inputPath.endsWith(QStringLiteral(".txt"), Qt::CaseInsensitive)
                ? QStringLiteral("text/plain")
                : QStringLiteral("image/jpeg"));
        filePart.setHeader(
            QNetworkRequest::ContentDispositionHeader,
            QStringLiteral("form-data; name=\"images\"; filename=\"%1\"")
                .arg(QFileInfo(inputPath).fileName()));
        filePart.setBodyDevice(file);
        multiPart->append(filePart);
    }

    QNetworkRequest request{nodeOdmUrl(QStringLiteral("/task/new"))};
    request.setRawHeader("set-uuid", _odmTaskUuid.toUtf8());
    request.setTransferTimeout(0);
    QNetworkReply *reply = _nodeOdmNetworkManager->post(request, multiPart);
    multiPart->setParent(reply);

    _setOdmState(OdmState::Uploading, 0);
    connect(reply, &QNetworkReply::uploadProgress, this, [this](qint64 sent, qint64 total) {
        if (total <= 0) {
            return;
        }
        const int progress = qBound(0, static_cast<int>((sent * 100) / total), 100);
        if (progress != _odmProgress) {
            _setOdmState(OdmState::Uploading, progress);
        }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray body = reply->readAll();
        const QString error = nodeOdmReplyError(reply, body);
        reply->deleteLater();
        if (!error.isEmpty()) {
            _failOdm(tr("NodeODM rejected the mission upload: %1").arg(error));
            return;
        }

        const QString returnedUuid = QJsonDocument::fromJson(body)
                                         .object()
                                         .value(QStringLiteral("uuid"))
                                         .toString();
        if (returnedUuid.isEmpty()) {
            _failOdm(tr("NodeODM did not return a task identifier."));
            return;
        }
        _odmTaskUuid = returnedUuid;
        _setOdmState(OdmState::Queued, 0);
        _odmPollTimer.start();
        _pollNodeOdmTask();
    });
}

void RouteMappingPhotoController::_pollNodeOdmTask()
{
    if (_odmTaskUuid.isEmpty() || _odmPollReply || !odmRunning()
        || _odmState == OdmState::Uploading || _odmState == OdmState::Connecting
        || _odmState == OdmState::Downloading) {
        return;
    }

    QNetworkRequest request{nodeOdmUrl(
        QStringLiteral("/task/%1/info").arg(_odmTaskUuid))};
    request.setTransferTimeout(10000);
    _odmPollReply = _nodeOdmNetworkManager->get(request);
    QNetworkReply *reply = _odmPollReply;
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        _odmPollReply = nullptr;
        const QByteArray body = reply->readAll();
        const QString error = nodeOdmReplyError(reply, body);
        reply->deleteLater();
        if (!error.isEmpty()) {
            ++_odmPollFailures;
            const QString reconnecting = tr("NodeODM unreachable; retrying (%1)").arg(_odmPollFailures);
            _setOdmState(_odmState, _odmProgress, reconnecting);
            return;
        }

        _odmPollFailures = 0;
        const QJsonObject task = QJsonDocument::fromJson(body).object();
        const int statusCode = task.value(QStringLiteral("status"))
                                   .toObject()
                                   .value(QStringLiteral("code"))
                                   .toInt(-1);
        const int progress = qBound(
            0,
            qRound(task.value(QStringLiteral("progress")).toDouble()),
            100);

        switch (statusCode) {
        case 10:
            _setOdmState(OdmState::Queued, progress);
            break;
        case 20:
            _setOdmState(OdmState::Processing, progress);
            break;
        case 30:
            _failOdm(tr("NodeODM task %1 failed. Check the NodeODM container logs for details.")
                         .arg(_odmTaskUuid));
            break;
        case 40:
            _odmPollTimer.stop();
            _downloadNodeOdmOrthophoto();
            break;
        case 50:
            _failOdm(tr("NodeODM task %1 was canceled.").arg(_odmTaskUuid));
            break;
        default:
            _failOdm(tr("NodeODM returned an unknown task status (%1).").arg(statusCode));
            break;
        }
    });
}

void RouteMappingPhotoController::_downloadNodeOdmOrthophoto()
{
    _odmDownloadPath = QDir(_odmSessionDirectory).filePath(
        QStringLiteral(".nodeodm-%1.zip.part").arg(_odmTaskUuid));
    QFile::remove(_odmDownloadPath);

    _odmDownloadFile = new QFile(_odmDownloadPath, this);
    if (!_odmDownloadFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const QString error = _odmDownloadFile->errorString();
        _odmDownloadFile->deleteLater();
        _odmDownloadFile = nullptr;
        _failOdm(tr("Could not create the temporary NodeODM result file: %1").arg(error));
        return;
    }

    _setOdmState(OdmState::Downloading, 0);
    QNetworkRequest request{nodeOdmUrl(
        QStringLiteral("/task/%1/download/all.zip").arg(_odmTaskUuid))};
    request.setTransferTimeout(0);
    QNetworkReply *reply = _nodeOdmNetworkManager->get(request);
    connect(reply, &QNetworkReply::readyRead, this, [this, reply]() {
        if (_odmDownloadFile) {
            _odmDownloadFile->write(reply->readAll());
        }
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 received, qint64 total) {
        if (total <= 0) {
            return;
        }
        const int progress = qBound(0, static_cast<int>((received * 100) / total), 100);
        if (progress != _odmProgress) {
            _setOdmState(OdmState::Downloading, progress);
        }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        _finishNodeOdmDownload(reply);
        reply->deleteLater();
    });
}

void RouteMappingPhotoController::_finishNodeOdmDownload(QNetworkReply *reply)
{
    if (_odmDownloadFile) {
        _odmDownloadFile->write(reply->readAll());
        _odmDownloadFile->close();
        _odmDownloadFile->deleteLater();
        _odmDownloadFile = nullptr;
    }

    const QString error = nodeOdmReplyError(reply, {});
    if (!error.isEmpty()) {
        QFile::remove(_odmDownloadPath);
        _failOdm(tr("Could not download the NodeODM orthomosaic: %1").arg(error));
        return;
    }

    const QString expectedOrthophoto = QDir(_odmSessionDirectory).filePath(
        QString::fromLatin1(kOrthophotoArchivePath));
    if (!QGCZip::extractFile(
            _odmDownloadPath,
            QString::fromLatin1(kOrthophotoArchivePath),
            expectedOrthophoto)) {
        QFile::remove(_odmDownloadPath);
        _failOdm(tr("NodeODM completed, but its result did not contain the orthomosaic GeoTIFF."));
        return;
    }
    QFile::remove(_odmDownloadPath);

    _orthophotoPath = expectedOrthophoto;
    _odmComplete = true;
    _odmErrorMessage.clear();
    _setOdmState(OdmState::Complete, 100);
    _prepareOrthophotoOverlay();
    qCInfo(RouteMappingPhotoControllerLog)
        << "NodeODM orthomosaic saved to" << _orthophotoPath;
}

void RouteMappingPhotoController::_prepareOrthophotoOverlay()
{
    _orthophotoUrl.clear();
    _orthophotoNorthWest = {};
    _orthophotoSouthEast = {};
    emit orthophotoOverlayChanged();

    const QString gdalInfo = QStandardPaths::findExecutable(QStringLiteral("gdalinfo"));
    if (gdalInfo.isEmpty()) {
        qCWarning(RouteMappingPhotoControllerLog)
            << "gdalinfo is not installed; the GeoTIFF was saved but cannot be positioned on the Fly View map";
        return;
    }

    auto *process = new QProcess(this);
    process->setProgram(gdalInfo);
    process->setArguments({QStringLiteral("-json"), _orthophotoPath});
    connect(
        process,
        qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
        this,
        [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
            const QByteArray output = process->readAllStandardOutput();
            const QByteArray errorOutput = process->readAllStandardError();
            process->deleteLater();
            if (exitStatus != QProcess::NormalExit || exitCode != 0) {
                qCWarning(RouteMappingPhotoControllerLog)
                    << "gdalinfo could not read the orthomosaic bounds:" << errorOutput;
                return;
            }

            const QJsonObject extent = QJsonDocument::fromJson(output)
                                           .object()
                                           .value(QStringLiteral("wgs84Extent"))
                                           .toObject();
            const QJsonArray rings = extent.value(QStringLiteral("coordinates")).toArray();
            double minLongitude = std::numeric_limits<double>::max();
            double maxLongitude = std::numeric_limits<double>::lowest();
            double minLatitude = std::numeric_limits<double>::max();
            double maxLatitude = std::numeric_limits<double>::lowest();
            bool foundCoordinate = false;
            for (const QJsonValue &ringValue : rings) {
                const QJsonArray ring = ringValue.toArray();
                for (const QJsonValue &pointValue : ring) {
                    const QJsonArray point = pointValue.toArray();
                    if (point.size() < 2 || !point.at(0).isDouble() || !point.at(1).isDouble()) {
                        continue;
                    }
                    const double longitude = point.at(0).toDouble();
                    const double latitude = point.at(1).toDouble();
                    minLongitude = qMin(minLongitude, longitude);
                    maxLongitude = qMax(maxLongitude, longitude);
                    minLatitude = qMin(minLatitude, latitude);
                    maxLatitude = qMax(maxLatitude, latitude);
                    foundCoordinate = true;
                }
            }

            if (!foundCoordinate
                || minLongitude >= maxLongitude
                || minLatitude >= maxLatitude) {
                qCWarning(RouteMappingPhotoControllerLog)
                    << "The orthomosaic does not contain a usable WGS84 extent";
                return;
            }

            _orthophotoNorthWest = QGeoCoordinate(maxLatitude, minLongitude);
            _orthophotoSouthEast = QGeoCoordinate(minLatitude, maxLongitude);
            _orthophotoUrl = QUrl::fromLocalFile(_orthophotoPath).toString();
            emit orthophotoOverlayChanged();
            qCInfo(RouteMappingPhotoControllerLog)
                << "Orthomosaic overlay bounds"
                << _orthophotoNorthWest << _orthophotoSouthEast;
        });
    process->start();
}

void RouteMappingPhotoController::_setOdmState(
    OdmState state, int progress, const QString &detail)
{
    const int boundedProgress = qBound(0, progress, 100);
    if (_odmState == state
        && _odmProgress == boundedProgress
        && _odmStateDetail == detail) {
        return;
    }
    _odmState = state;
    _odmProgress = boundedProgress;
    _odmStateDetail = detail;
    _writeOdmStateFile();
    emit reconstructionStateChanged();
}

void RouteMappingPhotoController::_failOdm(const QString &errorMessage)
{
    _odmPollTimer.stop();
    _odmErrorMessage = errorMessage;
    _setOdmState(OdmState::Failed, _odmProgress, errorMessage);
    qCWarning(RouteMappingPhotoControllerLog) << errorMessage;
    emit odmError(errorMessage);
}

void RouteMappingPhotoController::_writeOdmStateFile() const
{
    if (_odmSessionDirectory.isEmpty()) {
        return;
    }

    QJsonObject state;
    state.insert(QStringLiteral("taskUuid"), _odmTaskUuid);
    state.insert(QStringLiteral("endpoint"), nodeOdmEndpointText());
    state.insert(QStringLiteral("status"), _nodeOdmStatusText());
    state.insert(QStringLiteral("progress"), _odmProgress);
    state.insert(QStringLiteral("detail"), _odmStateDetail);
    state.insert(QStringLiteral("updatedAtUtc"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    if (!_orthophotoPath.isEmpty()) {
        state.insert(QStringLiteral("orthophotoPath"), _orthophotoPath);
    }
    if (!_odmErrorMessage.isEmpty()) {
        state.insert(QStringLiteral("error"), _odmErrorMessage);
    }

    QSaveFile stateFile(QDir(_odmSessionDirectory).filePath(QStringLiteral("nodeodm_task.json")));
    if (stateFile.open(QIODevice::WriteOnly)) {
        stateFile.write(QJsonDocument(state).toJson(QJsonDocument::Indented));
        if (!stateFile.commit()) {
            qCWarning(RouteMappingPhotoControllerLog)
                << "Could not commit NodeODM state file" << stateFile.fileName();
        }
    }
}

void RouteMappingPhotoController::_scheduleCapturePump()
{
    if (_capturePumpRunning) {
        return;
    }
    _capturePumpRunning = true;
    QTimer::singleShot(0, this, &RouteMappingPhotoController::_pumpCaptureQueue);
}

void RouteMappingPhotoController::_finishSessionIfReady()
{
    if (!_finishRequested || _waitingForPiSession || _captureUdpInFlight || !_pendingCaptures.isEmpty()) {
        return;
    }

    _finishRequested = false;
    if (_sessionActive) {
        _sessionActive = false;
        emit sessionActiveChanged();
    }
    if (_fetcher) {
        // All capture commands are now represented in the fetch queue. Let its
        // transfers finish before VIDEO_RESUME closes the remote session.
        _fetcher->finishSession();
    }
    emit reconstructionStateChanged();
}

void RouteMappingPhotoController::_completeCaptureAttempt(
    int sequence,
    double latitude,
    double longitude,
    double altitude,
    double heading,
    bool success,
    const QString &remotePhotoPath,
    const QString &remoteThumbnailPath)
{
    _captureUdpInFlight = false;
    _notifyPendingCaptureCountChanged();

    const QString imagePath = imagePathForSequence(sequence);
    if (success && !imagePath.isEmpty() && _fetcher) {
        if (!remotePhotoPath.isEmpty()) {
            qCInfo(RouteMappingPhotoControllerLog)
                << "SCP using Pi path from trigger for seq" << sequence << remotePhotoPath;
        }
        if (!remoteThumbnailPath.isEmpty()) {
            qCInfo(RouteMappingPhotoControllerLog)
                << "Thumbnail path from trigger for seq" << sequence << remoteThumbnailPath;
        }
        _fetcher->fetchPhotoBySequence(
            sequence, imagePath, sequence, remotePhotoPath, remoteThumbnailPath);
        emit captureRequested(sequence, imagePath);
    } else {
        Q_UNUSED(latitude);
        Q_UNUSED(longitude);
        Q_UNUSED(altitude);
        Q_UNUSED(heading);
        qCWarning(RouteMappingPhotoControllerLog)
            << "Route Mapping CAPTURE seq" << sequence << "failed after UDP retries";
    }

    _capturePumpRunning = false;
    QTimer::singleShot(100, this, &RouteMappingPhotoController::_scheduleCapturePump);
    _finishSessionIfReady();
}

void RouteMappingPhotoController::_pumpCaptureQueue()
{
    _capturePumpRunning = false;

    if (!_fetcher || _sessionDirectory.isEmpty()) {
        return;
    }

    if (!_captureEnabled) {
        return;
    }

    if (_captureUdpInFlight || _pendingCaptures.isEmpty()) {
        _finishSessionIfReady();
        return;
    }

    const bool piReady = _sessionActive && !_fetcher->piSessionPath().isEmpty()
                         && !_fetcher->piSessionStarting();
    if (_waitingForPiSession || !piReady) {
        QTimer::singleShot(400, this, &RouteMappingPhotoController::_pumpCaptureQueue);
        return;
    }

    const PendingCapture pending = _pendingCaptures.takeFirst();
    const QString imagePath = imagePathForSequence(pending.sequence);
    if (imagePath.isEmpty()) {
        emit captureFailed(pending.sequence, tr("No active Route Mapping photo session."));
        _scheduleCapturePump();
        return;
    }

    QDir().mkpath(_sessionDirectory);
    (void)_writeMetadata(
        pending.sequence,
        pending.nativeTriggerSequence,
        pending.latitude,
        pending.longitude,
        pending.altitude,
        pending.heading);

    _captureUdpInFlight = true;
    _inFlightCapture = pending;
    _inFlightCaptureValid = true;
    _notifyPendingCaptureCountChanged();
    _fetcher->triggerCaptureQueued(pending.sequence);
}

void RouteMappingPhotoController::_onTriggerCaptureFinished(
    int sequence, bool success, const QString &remotePhotoPath, const QString &remoteThumbnailPath)
{
    if (!_inFlightCaptureValid || _inFlightCapture.sequence != sequence) {
        return;
    }

    const PendingCapture capture = _inFlightCapture;
    _inFlightCaptureValid = false;
    _captureUdpInFlight = false;
    _notifyPendingCaptureCountChanged();

    if (!success) {
        PendingCapture retry = capture;
        retry.udpAttempts++;
        if (_captureEnabled && retry.udpAttempts <= 4) {
            _pendingCaptures.prepend(retry);
            _notifyPendingCaptureCountChanged();
            qCWarning(RouteMappingPhotoControllerLog)
                << "Re-queued Route Mapping CAPTURE seq" << retry.sequence << "attempt"
                << retry.udpAttempts;
            _capturePumpRunning = false;
            QTimer::singleShot(2000, this, &RouteMappingPhotoController::_pumpCaptureQueue);
            return;
        }
        qCWarning(RouteMappingPhotoControllerLog)
            << "Route Mapping CAPTURE seq" << sequence
            << "failed; no JPEG will be fetched";
        emit captureFailed(sequence, tr("The Raspberry Pi did not accept the capture command."));
        _completeCaptureAttempt(
            capture.sequence,
            capture.latitude,
            capture.longitude,
            capture.altitude,
            capture.heading,
            false,
            {},
            {});
        return;
    }

    _completeCaptureAttempt(
        capture.sequence,
        capture.latitude,
        capture.longitude,
        capture.altitude,
        capture.heading,
        true,
        remotePhotoPath,
        remoteThumbnailPath);
}

bool RouteMappingPhotoController::requestPhotoCapture(
    int sequence, quint32 nativeTriggerSequence, double latitude, double longitude, double altitude, double heading)
{
    if (!_captureEnabled || sequence < 1 || !_fetcher || _sessionDirectory.isEmpty()) {
        return false;
    }

    if (_requestedCaptureSequences.contains(sequence)) {
        qCWarning(RouteMappingPhotoControllerLog)
            << "Ignoring duplicate Route Mapping capture sequence" << sequence;
        return false;
    }
    if (_captureUdpInFlight) {
        // Allow one in-flight UDP command; additional sequences queue behind it.
    }

    PendingCapture pending;
    pending.sequence = sequence;
    pending.nativeTriggerSequence = nativeTriggerSequence;
    pending.latitude = latitude;
    pending.longitude = longitude;
    pending.altitude = altitude;
    pending.heading = heading;
    _requestedCaptureSequences.insert(sequence);
    _captureMetadata.insert(sequence, pending);
    _pendingCaptures.append(pending);
    _notifyPendingCaptureCountChanged();
    qCInfo(RouteMappingPhotoControllerLog)
        << "Queued Route Mapping capture seq" << sequence << "(queue depth" << _pendingCaptures.size() << ")";
    _scheduleCapturePump();
    emit reconstructionStateChanged();
    return true;
}
