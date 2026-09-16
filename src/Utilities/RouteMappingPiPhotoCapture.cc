#include "RouteMappingPiPhotoCapture.h"

#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"
#include "Vehicle.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QProcess>
#include <QtCore/QRandomGenerator>
#include <QtCore/QRegularExpression>
#include <QtCore/QTimer>
#include <QtCore/QTemporaryFile>

QGC_LOGGING_CATEGORY(RouteMappingPiPhotoCaptureLog, "Utilities.RouteMappingPiPhotoCapture")

RouteMappingPiPhotoCapture::RouteMappingPiPhotoCapture(QObject *parent)
    : QObject(parent)
{
    QString dirError;
    if (!_ensureLocalDirectory(&dirError)) {
        qCWarning(RouteMappingPiPhotoCaptureLog) << dirError;
        return;
    }
    QDir metadataDir(RouteMappingImageMetadata::metadataDirectory());
    if (!metadataDir.exists()) {
        metadataDir.mkpath(QStringLiteral("."));
    }
    qCInfo(RouteMappingPiPhotoCaptureLog)
        << "Pi photo save directory ready:" << localSaveDirectory();
}

RouteMappingPiPhotoCapture::~RouteMappingPiPhotoCapture()
{
    _cleanupProcess();
}

RouteMappingPiPhotoCapture *RouteMappingPiPhotoCapture::instance()
{
    static RouteMappingPiPhotoCapture s_instance;
    return &s_instance;
}

QString RouteMappingPiPhotoCapture::_sshTarget() const
{
    return QStringLiteral("%1@%2").arg(QLatin1String(kSshUser), QLatin1String(kSshHost));
}

QStringList RouteMappingPiPhotoCapture::_baseSshOptions() const
{
    return {
        QStringLiteral("-o"), QStringLiteral("BatchMode=yes"),
        QStringLiteral("-o"), QStringLiteral("ConnectTimeout=15"),
        QStringLiteral("-o"), QStringLiteral("StrictHostKeyChecking=accept-new"),
    };
}

void RouteMappingPiPhotoCapture::_setBusy(bool busy)
{
    if (_busy == busy) {
        return;
    }
    _busy = busy;
    emit busyChanged();
}

void RouteMappingPiPhotoCapture::_setError(const QString &error)
{
    _lastError = error;
    emit lastErrorChanged();
}

void RouteMappingPiPhotoCapture::_setBatchProgress(int completed, int total)
{
    if (_batchProgressCompleted == completed && _batchProgressTotal == total) {
        return;
    }
    _batchProgressCompleted = completed;
    _batchProgressTotal = total;
    emit batchProgressChanged();
}

void RouteMappingPiPhotoCapture::_cleanupProcess()
{
    if (!_process) {
        return;
    }
    _process->disconnect(this);
    if (_process->state() != QProcess::NotRunning) {
        _process->kill();
        _process->waitForFinished(3000);
    }
    _process->deleteLater();
    _process = nullptr;
}

QString RouteMappingPiPhotoCapture::localSaveDirectory()
{
    return QString::fromUtf8(kLocalSaveDir);
}

QString RouteMappingPiPhotoCapture::localMetadataDirectory()
{
    return RouteMappingImageMetadata::metadataDirectory();
}

bool RouteMappingPiPhotoCapture::ensureLocalSaveDirectory()
{
    QString error;
    if (!_ensureLocalDirectory(&error)) {
        _setError(error);
        return false;
    }
    QDir metadataDir(RouteMappingImageMetadata::metadataDirectory());
    if (!metadataDir.exists()) {
        metadataDir.mkpath(QStringLiteral("."));
    }
    return true;
}

bool RouteMappingPiPhotoCapture::_ensureLocalDirectory(QString *errorOut)
{
    QDir dir(QString::fromUtf8(kLocalSaveDir));
    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        if (errorOut) {
            *errorOut = QStringLiteral("Failed to create local directory: %1").arg(dir.absolutePath());
        }
        return false;
    }

    QTemporaryFile writeProbe(dir.filePath(QStringLiteral(".qgc_write_test_XXXXXX")));
    if (!writeProbe.open()) {
        if (errorOut) {
            *errorOut = QStringLiteral("Local directory is not writable: %1").arg(dir.absolutePath());
        }
        return false;
    }
    writeProbe.close();

    return true;
}

QString RouteMappingPiPhotoCapture::_allocateLocalFileName() const
{
    QDir dir(QString::fromUtf8(kLocalSaveDir));
    int maxNumber = 0;
    const QRegularExpression pattern(QStringLiteral("^image_(\\d+)\\.jpg$"),
                                     QRegularExpression::CaseInsensitiveOption);

    const QFileInfoList entries = dir.entryInfoList(
        {QStringLiteral("image_*.jpg")}, QDir::Files, QDir::Name);

    for (const QFileInfo &info : entries) {
        const QRegularExpressionMatch match = pattern.match(info.fileName());
        if (match.hasMatch()) {
            maxNumber = qMax(maxNumber, match.captured(1).toInt());
        }
    }

    for (int candidate = maxNumber + 1; candidate < maxNumber + 10000; ++candidate) {
        const QString path = dir.filePath(QStringLiteral("image_%1.jpg")
                                              .arg(candidate, 3, 10, QChar('0')));
        if (!QFile::exists(path)) {
            return path;
        }
    }

    return dir.filePath(QStringLiteral("image_%1.jpg")
                            .arg(maxNumber + 1, 3, 10, QChar('0')));
}

QString RouteMappingPiPhotoCapture::_allocateRemotePath() const
{
    return QStringLiteral("/tmp/qgc_route_proto_%1_%2.jpg")
        .arg(QDateTime::currentMSecsSinceEpoch())
        .arg(QRandomGenerator::global()->bounded(100000));
}

void RouteMappingPiPhotoCapture::_snapshotPendingTelemetry()
{
    _pendingTelemetry = RouteMappingImageTelemetry{};
    _pendingTelemetry.filename = QFileInfo(_lastLocalPath).fileName();
    _pendingTelemetry.sequence = RouteMappingImageMetadata::sequenceFromImageFileName(_lastLocalPath);
    _pendingTelemetry.missionRouteMappingId = RouteMappingImageMetadata::loadOrCreateMissionRouteMappingId();
    _pendingTelemetry.timestampUtc = QDateTime::currentDateTimeUtc();

    Vehicle *vehicle = MultiVehicleManager::instance()->activeVehicle();
    if (vehicle && vehicle->coordinate().isValid()) {
        _pendingTelemetry.coordinate = vehicle->coordinate();
        _pendingTelemetry.gpsValid = true;
        _pendingTelemetry.vehicleId = vehicle->id();
    }
}

void RouteMappingPiPhotoCapture::_writeMetadataForCurrentPhoto()
{
    QString metadataError;
    if (!RouteMappingImageMetadata::writeSidecar(_pendingTelemetry, &metadataError)) {
        qCWarning(RouteMappingPiPhotoCaptureLog) << metadataError;
    }
}

void RouteMappingPiPhotoCapture::captureOnePhoto()
{
    captureMultiplePhotos(1);
}

void RouteMappingPiPhotoCapture::captureMultiplePhotos(int count)
{
    if (_busy) {
        qCWarning(RouteMappingPiPhotoCaptureLog) << "Capture already in progress";
        return;
    }

    if (count < 1) {
        count = 1;
    }
    if (count > kMaxBatchSize) {
        count = kMaxBatchSize;
    }

    QString dirError;
    if (!_ensureLocalDirectory(&dirError)) {
        _setError(dirError);
        emit captureFailed(dirError);
        return;
    }

    _setError(QString());
    _beginSession(count);
}

void RouteMappingPiPhotoCapture::_beginSession(int photoCount)
{
    _sessionPhotoCount = photoCount;
    _sessionPhotosRemaining = photoCount;
    _sessionSuccessfulPaths.clear();
    _transferredLocalPaths.clear();
    _transferredRemotePaths.clear();
    _attemptNumber = 0;
    _step = Step::Idle;
    _cleanupAfterSuccess = false;

    _setBatchProgress(0, photoCount);
    _setBusy(true);

    qCInfo(RouteMappingPiPhotoCaptureLog) << "Starting batch session:" << photoCount << "photo(s)";

    _startNextPhotoInSession();
}

void RouteMappingPiPhotoCapture::_startNextPhotoInSession()
{
    if (_sessionPhotosRemaining <= 0) {
        _completeSession();
        return;
    }

    _attemptNumber = 0;
    _lastLocalPath = _allocateLocalFileName();
    while (_transferredLocalPaths.contains(_lastLocalPath)) {
        _lastLocalPath = _allocateLocalFileName();
    }
    emit lastLocalPathChanged();

    _remotePath = _allocateRemotePath();
    while (_transferredRemotePaths.contains(_remotePath)) {
        _remotePath = _allocateRemotePath();
    }

    _snapshotPendingTelemetry();

    _step = Step::RemoteCapture;

    qCInfo(RouteMappingPiPhotoCaptureLog)
        << "Photo" << (_batchProgressCompleted + 1) << "of" << _batchProgressTotal
        << "remote" << _remotePath << "local" << _lastLocalPath;

    _startRemoteCapture();
}

void RouteMappingPiPhotoCapture::_retryCurrentStep(const QString &reason)
{
    _attemptNumber++;
    if (_attemptNumber >= kMaxAttemptsPerPhoto) {
        _onPhotoPipelineFailed(
            QStringLiteral("%1 (failed after %2 attempts)").arg(reason).arg(kMaxAttemptsPerPhoto));
        return;
    }

    qCInfo(RouteMappingPiPhotoCaptureLog)
        << "Retrying photo" << (_batchProgressCompleted + 1)
        << "attempt" << (_attemptNumber + 1) << "of" << kMaxAttemptsPerPhoto << ":" << reason;

    QTimer::singleShot(kRetryDelayMs, this, [this]() {
        if (!_busy) {
            return;
        }
        if (_step == Step::RemoteCapture) {
            _remotePath = _allocateRemotePath();
            _startRemoteCapture();
        } else if (_step == Step::ScpTransfer) {
            _startScp();
        }
    });
}

void RouteMappingPiPhotoCapture::_startRemoteCapture()
{
    _cleanupProcess();
    _process = new QProcess(this);

    const QString remoteShell = QStringLiteral(
        "set -e; "
        "CAM=%1; OUT=%2; SVC=%3; "
        "test -x \"$CAM\" || { echo 'rpicam-still missing' >&2; exit 127; }; "
        "VIDEO_WAS=0; "
        "if systemctl is-active --quiet \"$SVC\"; then "
        "  if sudo -n systemctl stop \"$SVC\"; then VIDEO_WAS=1; "
        "  else echo 'Cannot stop wfb-camera (add passwordless sudo for systemctl stop/start wfb-camera.service)' >&2; exit 1; "
        "  fi; "
        "fi; "
        "cleanup() { if [ \"$VIDEO_WAS\" = 1 ]; then sudo -n systemctl start \"$SVC\" || true; fi; }; "
        "trap cleanup EXIT; "
        "\"$CAM\" --timeout 2000 --nopreview --autofocus-mode auto "
        "--width 4608 --height 2592 --quality 95 --output \"$OUT\""
    ).arg(QLatin1String(kRemoteCameraCommand),
          _remotePath,
          QLatin1String(kRemoteVideoService));

    QStringList args = _baseSshOptions();
    args << _sshTarget() << remoteShell;

    _step = Step::RemoteCapture;
    connect(_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RouteMappingPiPhotoCapture::_onSshCaptureFinished);

    qCInfo(RouteMappingPiPhotoCaptureLog) << "SSH capture:" << args;
    _process->start(QStringLiteral("ssh"), args);
}

void RouteMappingPiPhotoCapture::_onSshCaptureFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    const QByteArray stderrBytes = _process ? _process->readAllStandardError() : QByteArray();
    const QByteArray stdoutBytes = _process ? _process->readAllStandardOutput() : QByteArray();

    if (exitStatus != QProcess::NormalExit || exitCode != 0) {
        _retryCurrentStep(QStringLiteral("Remote capture failed (exit %1): %2 %3")
                              .arg(exitCode)
                              .arg(QString::fromUtf8(stderrBytes).trimmed())
                              .arg(QString::fromUtf8(stdoutBytes).trimmed()));
        return;
    }

    _step = Step::ScpTransfer;
    _startScp();
}

void RouteMappingPiPhotoCapture::_startScp()
{
    if (_transferredRemotePaths.contains(_remotePath)) {
        _retryCurrentStep(QStringLiteral("Refusing to transfer the same remote file twice"));
        return;
    }

    _cleanupProcess();
    _process = new QProcess(this);

    const QString remoteSpec = QStringLiteral("%1:%2").arg(_sshTarget(), _remotePath);

    QStringList args = _baseSshOptions();
    args << remoteSpec << _lastLocalPath;

    _step = Step::ScpTransfer;
    connect(_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RouteMappingPiPhotoCapture::_onScpFinished);

    qCInfo(RouteMappingPiPhotoCaptureLog) << "SCP:" << args;
    _process->start(QStringLiteral("scp"), args);
}

void RouteMappingPiPhotoCapture::_onScpFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    const QByteArray stderrBytes = _process ? _process->readAllStandardError() : QByteArray();

    if (exitStatus != QProcess::NormalExit || exitCode != 0) {
        _retryCurrentStep(QStringLiteral("SCP failed (exit %1): %2")
                              .arg(exitCode)
                              .arg(QString::fromUtf8(stderrBytes).trimmed()));
        return;
    }

    const QFileInfo localInfo(_lastLocalPath);
    if (!localInfo.exists() || localInfo.size() == 0) {
        _retryCurrentStep(QStringLiteral("Transfer finished but local file missing or empty: %1")
                              .arg(_lastLocalPath));
        return;
    }

    qCInfo(RouteMappingPiPhotoCaptureLog)
        << "Local file verified:" << _lastLocalPath << "size" << localInfo.size();

    _transferredLocalPaths.insert(_lastLocalPath);
    _transferredRemotePaths.insert(_remotePath);

    _cleanupAfterSuccess = true;
    _step = Step::RemoteCleanup;
    _startRemoteCleanup();
}

void RouteMappingPiPhotoCapture::_startRemoteCleanup()
{
    _cleanupProcess();
    _process = new QProcess(this);

    const QString remoteShell = QStringLiteral("rm -f %1").arg(_remotePath);
    QStringList args = _baseSshOptions();
    args << _sshTarget() << remoteShell;

    _step = Step::RemoteCleanup;
    connect(_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RouteMappingPiPhotoCapture::_onSshRemoveFinished);

    qCInfo(RouteMappingPiPhotoCaptureLog) << "SSH cleanup:" << args;
    _process->start(QStringLiteral("ssh"), args);
}

void RouteMappingPiPhotoCapture::_onSshRemoveFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    const QByteArray stderrBytes = _process ? _process->readAllStandardError() : QByteArray();
    _cleanupProcess();

    if (_cleanupAfterSuccess) {
        if (exitStatus != QProcess::NormalExit || exitCode != 0) {
            qCWarning(RouteMappingPiPhotoCaptureLog)
                << "Remote cleanup failed (non-fatal):" << exitCode << stderrBytes;
        }
        _onPhotoPipelineSucceeded();
        return;
    }

    _step = Step::Idle;
}

void RouteMappingPiPhotoCapture::_onPhotoPipelineSucceeded()
{
    _writeMetadataForCurrentPhoto();

    _sessionSuccessfulPaths.append(_lastLocalPath);
    _sessionPhotosRemaining--;
    _setBatchProgress(_batchProgressCompleted + 1, _batchProgressTotal);
    _setError(QString());

    emit captureSucceeded(_lastLocalPath);
    qCInfo(RouteMappingPiPhotoCaptureLog) << "Capture pipeline succeeded:" << _lastLocalPath;

    _cleanupAfterSuccess = false;
    _attemptNumber = 0;

    if (_sessionPhotosRemaining > 0) {
        _startNextPhotoInSession();
        return;
    }

    _completeSession();
}

void RouteMappingPiPhotoCapture::_onPhotoPipelineFailed(const QString &error)
{
    if (_sessionPhotoCount <= 1) {
        _abortSession(error);
        return;
    }

    const int photoIndex = _batchProgressCompleted + 1;
    qCWarning(RouteMappingPiPhotoCaptureLog)
        << "Batch photo" << photoIndex << "of" << _batchProgressTotal << "failed:" << error;

    _setError(error);
    _cleanupProcess();
    _cleanupAfterSuccess = false;
    _attemptNumber = 0;
    _sessionPhotosRemaining--;

    emit captureFailed(QStringLiteral("Photo %1/%2 failed: %3")
                           .arg(photoIndex)
                           .arg(_batchProgressTotal)
                           .arg(error));

    if (_sessionPhotosRemaining > 0) {
        _startNextPhotoInSession();
        return;
    }

    _completeSession();
}

void RouteMappingPiPhotoCapture::_abortSession(const QString &error)
{
    _setError(error);
    _cleanupProcess();
    _step = Step::Idle;
    _setBusy(false);
    _cleanupAfterSuccess = false;

    emit captureFailed(error);

    if (_sessionPhotoCount > 1) {
        emit batchCaptureCompleted(_sessionSuccessfulPaths.size(),
                                   _sessionPhotoCount,
                                   _sessionSuccessfulPaths);
    }
}

void RouteMappingPiPhotoCapture::_completeSession()
{
    _step = Step::Idle;
    _setBusy(false);
    _cleanupAfterSuccess = false;

    const int succeeded = _sessionSuccessfulPaths.size();
    qCInfo(RouteMappingPiPhotoCaptureLog)
        << "Batch session complete:" << succeeded << "of" << _sessionPhotoCount
        << "paths:" << _sessionSuccessfulPaths;

    emit batchCaptureCompleted(succeeded, _sessionPhotoCount, _sessionSuccessfulPaths);

    if (succeeded < _sessionPhotoCount) {
        const QString error = QStringLiteral("Batch incomplete: %1 of %2 photos saved")
                                  .arg(succeeded)
                                  .arg(_sessionPhotoCount);
        _setError(error);
        emit captureFailed(error);
    }
}
