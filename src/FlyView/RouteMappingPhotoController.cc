#include "RouteMappingPhotoController.h"

#include "RouteMappingPiPhotoFetcher.h"
#include "SettingsManager.h"
#include "AppSettings.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QFileInfo>
#include <QtCore/QUuid>
#include <QtConcurrent/QtConcurrentRun>
#include <QtCore/QFutureWatcher>
#include <QtCore/QTimer>

#include <utility>

QGC_LOGGING_CATEGORY(RouteMappingPhotoControllerLog, "FlyView.RouteMappingPhotoController")

RouteMappingPhotoController::RouteMappingPhotoController(QObject *parent)
    : QObject(parent)
{
}

void RouteMappingPhotoController::setCaptureEnabled(bool enabled)
{
    if (_captureEnabled == enabled) {
        return;
    }
    _captureEnabled = enabled;
    emit captureEnabledChanged();
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
    }
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
                               "  %1/Mission_<UTC time>_<id>/image_NNNN.jpg\n"
                               "  %1/Mission_<UTC time>_<id>/image_NNNN.json\n"
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

    const QString manifestPath = QDir(sessionPath).filePath(QStringLiteral("session_manifest.json"));
    QFile manifestFile(manifestPath);
    if (manifestFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        manifestFile.write(QJsonDocument(manifest).toJson(QJsonDocument::Indented));
    }
}

bool RouteMappingPhotoController::beginSession()
{
    if (_sessionActive) {
        return true;
    }
    if (_waitingForPiSession) {
        return true;
    }

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
    if (!QDir().mkpath(sessionPath)) {
        const QString errorMessage = tr("Could not create Route Mapping mission folder: %1").arg(sessionPath);
        qCWarning(RouteMappingPhotoControllerLog) << errorMessage;
        emit gcsSessionStartFailed(errorMessage);
        return false;
    }

    _sessionDirectory = sessionPath;
    emit sessionDirectoryChanged();

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
        _sessionDirectory.clear();
        emit sessionDirectoryChanged();
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
    _scheduleCapturePump();
}

void RouteMappingPhotoController::endSession()
{
    _pendingCaptures.clear();
    if (_waitingForPiSession) {
        _waitingForPiSession = false;
        emit piSessionPendingChanged();
    }
    if (_sessionActive) {
        _sessionActive = false;
        emit sessionActiveChanged();
    }

    // Stop accepting captures, but let already queued SCP transfers drain.
    // Cancelling here left most map tiles permanently empty at mission end.
    if (_fetcher) {
        _fetcher->finishSession();
    }
}

void RouteMappingPhotoController::cancelSession()
{
    _pendingCaptures.clear();
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
}

QString RouteMappingPhotoController::imagePathForSequence(int sequence) const
{
    if (sequence < 1 || _sessionDirectory.isEmpty()) {
        return {};
    }
    if (!_sessionActive && !_waitingForPiSession) {
        return {};
    }
    return QDir(_sessionDirectory).filePath(
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

bool RouteMappingPhotoController::_writeMetadata(int sequence, double latitude, double longitude, double altitude, double heading) const
{
    const QString metaPath = metadataPathForSequence(sequence);
    if (metaPath.isEmpty()) {
        return false;
    }

    QJsonObject object;
    object.insert(QStringLiteral("triggerIndex"), sequence);
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

void RouteMappingPhotoController::_scheduleCapturePump()
{
    if (_capturePumpRunning) {
        return;
    }
    _capturePumpRunning = true;
    QTimer::singleShot(0, this, &RouteMappingPhotoController::_pumpCaptureQueue);
}

void RouteMappingPhotoController::_completeCaptureAttempt(
    int sequence,
    double latitude,
    double longitude,
    double altitude,
    double heading,
    bool success,
    const QString &remotePhotoPath)
{
    _captureUdpInFlight = false;

    const QString imagePath = imagePathForSequence(sequence);
    if (success && !imagePath.isEmpty() && _fetcher) {
        _fetcher->fetchPhotoBySequence(sequence, imagePath, sequence, remotePhotoPath);
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
    _scheduleCapturePump();
}

void RouteMappingPhotoController::_pumpCaptureQueue()
{
    _capturePumpRunning = false;

    if (!_captureEnabled || !_fetcher || _sessionDirectory.isEmpty()) {
        return;
    }

    if (_captureUdpInFlight || _pendingCaptures.isEmpty()) {
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
        _scheduleCapturePump();
        return;
    }

    QDir().mkpath(_sessionDirectory);
    (void)_writeMetadata(
        pending.sequence,
        pending.latitude,
        pending.longitude,
        pending.altitude,
        pending.heading);

    _captureUdpInFlight = true;
    RouteMappingPiPhotoFetcher *fetcher = _fetcher;
    const PendingCapture capture = pending;

    auto *watcher = new QFutureWatcher<std::pair<bool, QString>>(this);
    connect(
        watcher,
        &QFutureWatcher<std::pair<bool, QString>>::finished,
        this,
        [this, watcher, capture]() {
            const std::pair<bool, QString> result = watcher->result();
            watcher->deleteLater();

            if (!result.first) {
                PendingCapture retry = capture;
                retry.udpAttempts++;
                if (retry.udpAttempts <= 8) {
                    _pendingCaptures.prepend(retry);
                    qCWarning(RouteMappingPhotoControllerLog)
                        << "Re-queued Route Mapping CAPTURE seq" << retry.sequence << "attempt"
                        << retry.udpAttempts;
                    _captureUdpInFlight = false;
                    _capturePumpRunning = false;
                    QTimer::singleShot(1500, this, &RouteMappingPhotoController::_pumpCaptureQueue);
                    return;
                }
                _completeCaptureAttempt(
                    capture.sequence,
                    capture.latitude,
                    capture.longitude,
                    capture.altitude,
                    capture.heading,
                    false,
                    {});
                return;
            }
            _completeCaptureAttempt(
                capture.sequence,
                capture.latitude,
                capture.longitude,
                capture.altitude,
                capture.heading,
                result.first,
                result.second);
        });

    watcher->setFuture(QtConcurrent::run([fetcher, capture]() {
        QString remotePhotoPath;
        const bool ok = fetcher->triggerCapture(capture.sequence, &remotePhotoPath);
        return std::make_pair(ok, remotePhotoPath);
    }));
}

bool RouteMappingPhotoController::requestPhotoCapture(
    int sequence, double latitude, double longitude, double altitude, double heading)
{
    if (!_captureEnabled || sequence < 1 || !_fetcher || _sessionDirectory.isEmpty()) {
        return false;
    }

    for (const PendingCapture &existing : _pendingCaptures) {
        if (existing.sequence == sequence) {
            return true;
        }
    }
    if (_captureUdpInFlight) {
        // Allow one in-flight UDP command; additional sequences queue behind it.
    }

    PendingCapture pending;
    pending.sequence = sequence;
    pending.latitude = latitude;
    pending.longitude = longitude;
    pending.altitude = altitude;
    pending.heading = heading;
    _pendingCaptures.append(pending);
    qCInfo(RouteMappingPhotoControllerLog)
        << "Queued Route Mapping capture seq" << sequence << "(queue depth" << _pendingCaptures.size() << ")";
    _scheduleCapturePump();
    return true;
}
