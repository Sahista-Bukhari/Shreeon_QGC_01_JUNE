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
#include <QtCore/QDir>
#include <QtCore/QUuid>
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

void RouteMappingPhotoController::_removeEmptySessionDirectory(const QString &sessionPath) const
{
    if (sessionPath.isEmpty()) {
        return;
    }

    QDir sessionDir(sessionPath);
    if (!sessionDir.exists()) {
        return;
    }

    const QStringList entries = sessionDir.entryList(QDir::NoDotAndDotDot | QDir::AllEntries);
    if (!entries.isEmpty()) {
        return;
    }

    if (sessionDir.rmdir(sessionPath)) {
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

    _finishRequested = false;
    _requestedCaptureSequences.clear();
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
        _removeEmptySessionDirectory(failedSessionPath);
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
}

void RouteMappingPhotoController::cancelSession()
{
    _pendingCaptures.clear();
    _notifyPendingCaptureCountChanged();
    _requestedCaptureSequences.clear();
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
}

void RouteMappingPhotoController::discardSessionStorage()
{
    const QString sessionPath = _sessionDirectory;
    cancelSession();
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
    _pendingCaptures.append(pending);
    _notifyPendingCaptureCountChanged();
    qCInfo(RouteMappingPhotoControllerLog)
        << "Queued Route Mapping capture seq" << sequence << "(queue depth" << _pendingCaptures.size() << ")";
    _scheduleCapturePump();
    return true;
}
