#include "RouteMappingPiPhotoFetcher.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QFile>
#include <QtCore/QProcess>
#include <QtCore/QRegularExpression>
#include <QtConcurrent/QtConcurrentRun>
#include <QtCore/QElapsedTimer>
#include <QtCore/QThread>
#include <QtCore/QTimer>
#include <QtGui/QImageReader>
#include <QtNetwork/QHostAddress>
#include <QtNetwork/QUdpSocket>

#include <memory>

QGC_LOGGING_CATEGORY(RouteMappingPiPhotoFetcherLog, "FlyView.RouteMappingPiPhotoFetcher")

namespace {

bool remoteScpTargetMissing(const QString &stderrText)
{
    return stderrText.contains(QStringLiteral("No such file"), Qt::CaseInsensitive)
        || stderrText.contains(QStringLiteral("not found"), Qt::CaseInsensitive);
}

// Wire format (keep in sync with deploy/pi-route-mapping/shreeon_route_mapping.py CAPTURE reply):
//   QUEUED seq=N path=/…/image_NNNN_gcs_NNNN_<ts>.jpg thumb=/…/image_NNNN_thumb.jpg
bool applyCaptureAckPaths(
    int sequence,
    int ackSequence,
    const QString &photoRoot,
    const QString &fullPath,
    const QString &explicitThumb,
    QString *remotePhotoPath,
    QString *remoteThumbnailPath)
{
    const QString path = QDir::cleanPath(fullPath);
    if (ackSequence != sequence) {
        const QString expectedPrefix = QStringLiteral("image_%1_").arg(sequence, 4, 10, QChar('0'));
        if (!path.contains(expectedPrefix)) {
            return false;
        }
        qCInfo(RouteMappingPiPhotoFetcherLog)
            << "CAPTURE ack seq" << ackSequence << "!= requested" << sequence
            << "— accepting path that names GCS sequence";
    }
    const QString root = QDir::cleanPath(photoRoot);
    if (!path.startsWith(root + QLatin1Char('/'))) {
        return false;
    }
    if (remotePhotoPath) {
        *remotePhotoPath = path;
    }
    if (remoteThumbnailPath) {
        if (!explicitThumb.trimmed().isEmpty()) {
            const QString thumbPath = QDir::cleanPath(explicitThumb.trimmed());
            if (!thumbPath.startsWith(root + QLatin1Char('/'))) {
                remoteThumbnailPath->clear();
            } else {
                *remoteThumbnailPath = thumbPath;
            }
        } else {
            const QFileInfo imageInfo(path);
            const QString thumbPath = QDir::cleanPath(
                imageInfo.dir().filePath(
                    QStringLiteral("image_%1_thumb.jpg").arg(sequence, 4, 10, QChar('0'))));
            if (thumbPath.startsWith(root + QLatin1Char('/'))) {
                *remoteThumbnailPath = thumbPath;
            } else {
                remoteThumbnailPath->clear();
            }
        }
    }
    return true;
}

constexpr int kMaxFetchAttempts = 400;
constexpr int kMaxConcurrentFetches = 2;
constexpr int kMaxConcurrentFullResDrain = 1;
constexpr int kCaptureUdpAckAttempts = 1;
constexpr int kSshPrecheckAttempts = 3;
constexpr int kSshPrecheckRetryDelayMs = 1500;
constexpr int kCaptureUdpAckTimeoutMs = 2500;
constexpr int kRetryDelayMs = 3000;
constexpr int kMinDownloadedJpegBytes = 8192;
constexpr int kRetryDelayFirstMs = 500;
constexpr int kRetryDelayPlannedPathMs = 750;
constexpr int kRetryDelayRemoteMissingMs = 750;
constexpr int kFastRetryAttempts = 3;
constexpr int kProcessTimeoutMs = 30000;
constexpr int kSshPrecheckTimeoutMs = 12000;
constexpr int kVideoPauseReplyTimeoutMs = 8000;
constexpr int kStatusReplyTimeoutMs = 4000;
constexpr int kStatusQueryAttempts = 6;
constexpr int kPiVideoPauseSettleMs = 2500;
constexpr int kCaptureSshTriggerTimeoutMs = 12000;

const QRegularExpression kCaptureUdpAcceptableReply(
    QStringLiteral(
        "^(QUEUED(\\s+seq=\\d+(\\s+path=/[^\\s]+(\\s+thumb=/[^\\s]+)?)?)?|BUSY)$"),
    QRegularExpression::CaseInsensitiveOption);

QString trimmedProcessOutput(QProcess &process)
{
    return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
}

QString trimmedProcessError(QProcess &process)
{
    return QString::fromUtf8(process.readAllStandardError()).trimmed();
}

bool runProcess(QProcess &process, int timeoutMs, QString *errorMessage)
{
    process.start();
    if (!process.waitForStarted(timeoutMs)) {
        if (errorMessage) {
            *errorMessage = process.errorString();
        }
        return false;
    }

    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(1000);
        if (errorMessage) {
            *errorMessage = QObject::tr("Timed out waiting for %1").arg(process.program());
        }
        return false;
    }

    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        if (errorMessage) {
            const QString stderrText = trimmedProcessError(process);
            const QString stdoutText = trimmedProcessOutput(process);
            if (!stderrText.isEmpty()) {
                *errorMessage = stderrText;
            } else if (!stdoutText.isEmpty()) {
                *errorMessage = stdoutText;
            } else {
                *errorMessage = QObject::tr("%1 failed with exit code %2")
                                    .arg(process.program())
                                    .arg(process.exitCode());
            }
        }
        return false;
    }

    return true;
}

QString shellQuote(const QString &value)
{
    QString quoted = value;
    quoted.replace(QLatin1Char('\''), QStringLiteral("'\\''"));
    return QStringLiteral("'%1'").arg(quoted);
}
} // namespace

RouteMappingPiPhotoFetcher::RouteMappingPiPhotoFetcher(QObject *parent)
    : QObject(parent)
{
}

void RouteMappingPiPhotoFetcher::setPiHost(const QString &host)
{
    const QString trimmed = host.trimmed();
    if (_piHost == trimmed) {
        return;
    }
    _piHost = trimmed;
    emit piHostChanged();
}

void RouteMappingPiPhotoFetcher::setPiUser(const QString &user)
{
    const QString trimmed = user.trimmed();
    if (_piUser == trimmed) {
        return;
    }
    _piUser = trimmed;
    emit piUserChanged();
}

void RouteMappingPiPhotoFetcher::setPiPhotoRoot(const QString &root)
{
    const QString trimmed = root.trimmed();
    if (_piPhotoRoot == trimmed) {
        return;
    }
    _piPhotoRoot = trimmed;
    emit piPhotoRootChanged();
}

void RouteMappingPiPhotoFetcher::setPiTriggerPort(int port)
{
    if (_piTriggerPort == port) {
        return;
    }
    _piTriggerPort = port;
    emit piTriggerPortChanged();
}

void RouteMappingPiPhotoFetcher::setEnabled(bool enabled)
{
    if (_enabled == enabled) {
        return;
    }
    _enabled = enabled;
    emit enabledChanged();
}

void RouteMappingPiPhotoFetcher::beginSessionAsync()
{
    if (_piSessionStarting) {
        return;
    }

    resetSession();
    _piSessionStarting = true;
    emit piSessionStartingChanged();

    const quint64 generation = _generation;
    RouteMappingPiPhotoFetcher *const self = this;
    (void)QtConcurrent::run([self, generation]() {
        QString errorMessage;
        QString sessionPath;
        bool sshPrecheckFailed = false;
        bool success = false;
        bool videoPaused = false;

        for (int attempt = 0; attempt < kSshPrecheckAttempts; ++attempt) {
            if (self->_runSshPrecheck(&errorMessage)) {
                sshPrecheckFailed = false;
                break;
            }
            sshPrecheckFailed = true;
            if (attempt + 1 < kSshPrecheckAttempts) {
                QThread::msleep(kSshPrecheckRetryDelayMs);
            }
        }

        if (sshPrecheckFailed) {
            qCWarning(RouteMappingPiPhotoFetcherLog)
                << "SSH precheck failed after" << kSshPrecheckAttempts
                << "attempts; skipping VIDEO_PAUSE:" << errorMessage;
        } else if (!self->_sendVideoPauseAndWaitForSession(&sessionPath, &errorMessage)) {
            success = false;
        } else {
            videoPaused = true;
            const QString photoRoot = QDir::cleanPath(self->_piPhotoRoot);
            if (!sessionPath.startsWith(photoRoot + QLatin1Char('/'))) {
                errorMessage = RouteMappingPiPhotoFetcher::tr(
                                   "Pi returned a photo session outside the configured root: %1")
                                   .arg(sessionPath);
                success = false;
            } else {
                success = true;
            }
        }

        if (!success && videoPaused) {
            qCInfo(RouteMappingPiPhotoFetcherLog)
                << "Rolling back Pi VIDEO_PAUSE after failed mapping session start";
            (void)self->_sendRemoteUdpCommand(QStringLiteral("VIDEO_RESUME"));
        }

        QMetaObject::invokeMethod(
            self,
            [self, generation, success, sshPrecheckFailed, sessionPath, errorMessage]() {
                self->_completeBeginSessionOnMainThread(
                    generation, success, sshPrecheckFailed, sessionPath, errorMessage);
            },
            Qt::QueuedConnection);
    });
}

bool RouteMappingPiPhotoFetcher::beginSession()
{
    beginSessionAsync();
    return true;
}

void RouteMappingPiPhotoFetcher::_completeBeginSessionOnMainThread(
    quint64 generation,
    bool success,
    bool hadSshPrecheckFailure,
    const QString &sessionPath,
    const QString &errorMessage)
{
    if (_piSessionStarting) {
        _piSessionStarting = false;
        emit piSessionStartingChanged();
    }

    if (generation != _generation) {
        return;
    }

    if (success) {
        _piSessionPath = sessionPath;
        emit piSessionPathChanged();
        qCInfo(RouteMappingPiPhotoFetcherLog) << "Pi mapping photo session:" << _piSessionPath;
        if (hadSshPrecheckFailure) {
            emit sshPrecheckFailed(errorMessage);
        }
        emit piSessionBeginComplete(true);
        return;
    }

    _acceptingCaptures = false;
    if (hadSshPrecheckFailure) {
        qCWarning(RouteMappingPiPhotoFetcherLog) << "Route Mapping SSH precheck failed:" << errorMessage;
        emit sshPrecheckFailed(errorMessage);
    } else {
        qCWarning(RouteMappingPiPhotoFetcherLog) << "Could not start Pi photo session:" << errorMessage;
        emit sessionStartFailed(errorMessage);
    }
    emit piSessionBeginComplete(false);
}

void RouteMappingPiPhotoFetcher::finishSession()
{
    _acceptingCaptures = false;
    _tryCompleteSessionEnd();
}

void RouteMappingPiPhotoFetcher::haltNewCaptures()
{
    _acceptingCaptures = false;
}

void RouteMappingPiPhotoFetcher::resetSession()
{
    if (_piSessionStarting) {
        _piSessionStarting = false;
        emit piSessionStartingChanged();
    }
    ++_generation;
    _downloadedRemotePaths.clear();
    if (!_queue.isEmpty() || !_deferredFullResQueue.isEmpty() || _deferredFullResActiveCount > 0) {
        _queue.clear();
        _deferredFullResQueue.clear();
        _deferredFullResActiveCount = 0;
        emit pendingFetchCountChanged();
    }
    _activeFetchCount = 0;
    _liveFetchQueueDrainedEmitted = false;
    _acceptingCaptures = true;
    if (!_piSessionPath.isEmpty()) {
        _piSessionPath.clear();
        emit piSessionPathChanged();
    }
}

void RouteMappingPiPhotoFetcher::cancelSession()
{
    ++_generation;
    _acceptingCaptures = false;
    if (!_piSessionPath.isEmpty()) {
        _piSessionPath.clear();
        emit piSessionPathChanged();
    }
    if (!_queue.isEmpty() || !_deferredFullResQueue.isEmpty() || _deferredFullResActiveCount > 0) {
        _queue.clear();
        _deferredFullResQueue.clear();
        _deferredFullResActiveCount = 0;
        emit pendingFetchCountChanged();
    }
    _activeFetchCount = 0;
    _liveFetchQueueDrainedEmitted = false;
}

QString RouteMappingPiPhotoFetcher::_sshTarget() const
{
    return QStringLiteral("%1@%2").arg(_piUser, _piHost);
}

QStringList RouteMappingPiPhotoFetcher::_baseSshOptions()
{
    const QString controlPath = QDir::temp().filePath(QStringLiteral("qgc-pi-%r@%h:%p"));
    return {
        QStringLiteral("-o"),
        QStringLiteral("BatchMode=yes"),
        QStringLiteral("-o"),
        QStringLiteral("ConnectTimeout=5"),
        QStringLiteral("-o"),
        QStringLiteral("StrictHostKeyChecking=accept-new"),
        QStringLiteral("-o"),
        QStringLiteral("ControlMaster=auto"),
        QStringLiteral("-o"),
        QStringLiteral("ControlPersist=60"),
        QStringLiteral("-o"),
        QStringLiteral("ControlPath=%1").arg(controlPath),
    };
}

void RouteMappingPiPhotoFetcher::warmUpConnection()
{
#if defined(Q_OS_WIN)
    return;
#else
    if (!_enabled || _piHost.isEmpty() || _piUser.isEmpty()) {
        return;
    }

    RouteMappingPiPhotoFetcher *const self = this;
    (void)QtConcurrent::run([self]() {
        QString errorMessage;
        if (!self->_runSshPrecheck(&errorMessage)) {
            qCInfo(RouteMappingPiPhotoFetcherLog)
                << "Optional SSH warm-up did not complete; session startup will retry:"
                << errorMessage;
            return;
        }
        qCInfo(RouteMappingPiPhotoFetcherLog) << "SSH ControlMaster warm-up complete for" << self->_sshTarget();
    });
#endif
}

bool RouteMappingPiPhotoFetcher::testConnection() const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(this);
    return false;
#else
    QString errorMessage;
    if (!_runSshPrecheck(&errorMessage)) {
        qCWarning(RouteMappingPiPhotoFetcherLog) << "SSH test failed:" << errorMessage;
        return false;
    }
    return true;
#endif
}

bool RouteMappingPiPhotoFetcher::_runSshPrecheck(QString *errorMessage) const
{
#if defined(Q_OS_WIN)
    if (errorMessage) {
        *errorMessage = tr("SSH photo transfer is not supported on Windows");
    }
    return false;
#else
    if (_piHost.isEmpty() || _piUser.isEmpty()) {
        if (errorMessage) {
            *errorMessage = tr("Pi SSH host or user is empty");
        }
        return false;
    }

    QProcess process;
    process.setProgram(QStringLiteral("ssh"));
    QStringList arguments = _baseSshOptions();
    arguments << _sshTarget() << QStringLiteral("true");
    process.setArguments(arguments);
    return runProcess(process, kSshPrecheckTimeoutMs, errorMessage);
#endif
}

bool RouteMappingPiPhotoFetcher::_triggerCaptureViaSsh(
    int sequence, QString *remotePhotoPath, QString *remoteThumbnailPath, QString *errorMessage) const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(sequence);
    Q_UNUSED(remotePhotoPath);
    Q_UNUSED(remoteThumbnailPath);
    if (errorMessage) {
        *errorMessage = tr("SSH capture trigger is not supported on Windows");
    }
    return false;
#else
    if (_piHost.isEmpty() || _piUser.isEmpty() || sequence < 1) {
        if (errorMessage) {
            *errorMessage = tr("Pi SSH host, user, or sequence is invalid");
        }
        return false;
    }

    QProcess ssh;
    ssh.setProgram(QStringLiteral("ssh"));
    QStringList args = _baseSshOptions();
    args << _sshTarget()
         << QStringLiteral("/home/shreeon/capture.sh")
         << QString::number(sequence);
    ssh.setArguments(args);

    if (!runProcess(ssh, kCaptureSshTriggerTimeoutMs, errorMessage)) {
        return false;
    }

    const QString response = trimmedProcessOutput(ssh);
    if (_parseCaptureUdpResponse(sequence, response, remotePhotoPath, remoteThumbnailPath)) {
        return true;
    }

    if (errorMessage && errorMessage->isEmpty()) {
        *errorMessage = tr("Unexpected SSH capture reply: %1").arg(response);
    }
    return false;
#endif
}

bool RouteMappingPiPhotoFetcher::_queryPiSessionPath(QString *sessionPath, QString *errorMessage) const
{
    static const QRegularExpression statusReply(QStringLiteral("^SESSION\\s+(/[^\\r\\n]+)$"));
    QString lastResponse;
    QString lastError;

    for (int attempt = 0; attempt < kStatusQueryAttempts; ++attempt) {
        if (attempt > 0) {
            QThread::msleep(400);
        }

        QString response;
        if (!_requestRemoteUdpCommand(
                QStringLiteral("STATUS"), &response, &lastError, kStatusReplyTimeoutMs, &statusReply)) {
            continue;
        }

        const QRegularExpressionMatch match = statusReply.match(response.trimmed());
        if (!match.hasMatch()) {
            lastResponse = response.trimmed();
            continue;
        }

        if (sessionPath) {
            *sessionPath = QDir::cleanPath(match.captured(1));
        }
        return true;
    }

    if (errorMessage) {
        if (!lastResponse.isEmpty()) {
            *errorMessage = tr(
                "Pi has no active mapping photo session (STATUS returned %1). "
                "Send VIDEO_PAUSE before capture and ensure route-mapping-capture.service is running.")
                .arg(lastResponse);
        } else if (!lastError.isEmpty()) {
            *errorMessage = lastError;
        } else {
            *errorMessage = tr("Timed out waiting for the Pi STATUS reply");
        }
    }
    return false;
}

bool RouteMappingPiPhotoFetcher::_sendVideoPauseAndWaitForSession(
    QString *sessionPath, QString *errorMessage) const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(sessionPath);
    if (errorMessage) {
        *errorMessage = tr("Pi UDP session control is not supported on Windows");
    }
    return false;
#else
    if (_piHost.isEmpty()) {
        if (errorMessage) {
            *errorMessage = tr("Pi host is empty");
        }
        return false;
    }

    QUdpSocket socket;
    if (!socket.bind(QHostAddress::AnyIPv4, 0)) {
        if (errorMessage) {
            *errorMessage = socket.errorString();
        }
        return false;
    }

    const QByteArray payload = QByteArrayLiteral("VIDEO_PAUSE");
    if (socket.writeDatagram(payload, QHostAddress(_piHost), static_cast<quint16>(_piTriggerPort)) != payload.size()) {
        if (errorMessage) {
            *errorMessage = socket.errorString();
        }
        return false;
    }

    static const QRegularExpression sessionReply(
        QStringLiteral("^OK\\s+session=(/[^\\r\\n]+)$"));

    bool pauseAcknowledged = false;
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < kVideoPauseReplyTimeoutMs) {
        const int remaining = kVideoPauseReplyTimeoutMs - static_cast<int>(timer.elapsed());
        if (!socket.waitForReadyRead(qMax(remaining, 1))) {
            break;
        }

        while (socket.hasPendingDatagrams()) {
            QByteArray datagram;
            datagram.resize(static_cast<int>(socket.pendingDatagramSize()));
            if (socket.readDatagram(datagram.data(), datagram.size()) < 0) {
                continue;
            }
            const QString reply = QString::fromUtf8(datagram).trimmed();
            const QRegularExpressionMatch match = sessionReply.match(reply);
            if (match.hasMatch()) {
                const QString path = QDir::cleanPath(match.captured(1));
                if (sessionPath) {
                    *sessionPath = path;
                }
                qCInfo(RouteMappingPiPhotoFetcherLog) << "VIDEO_PAUSE session" << path;
                return true;
            }
            if (reply.compare(QStringLiteral("OK"), Qt::CaseInsensitive) == 0) {
                pauseAcknowledged = true;
                qCInfo(RouteMappingPiPhotoFetcherLog)
                    << "VIDEO_PAUSE bare OK received; will query STATUS after Pi settles";
                continue;
            }
            qCInfo(RouteMappingPiPhotoFetcherLog)
                << "Ignoring Pi UDP reply while waiting for VIDEO_PAUSE session path:" << reply;
        }
    }

    Q_UNUSED(pauseAcknowledged);
    // pause_live_video() stops wfb-camera and sleeps ~2s before the session exists.
    qCInfo(RouteMappingPiPhotoFetcherLog)
        << "Waiting" << kPiVideoPauseSettleMs
        << "ms for Pi VIDEO_PAUSE to finish before STATUS";
    QThread::msleep(kPiVideoPauseSettleMs);
    return _queryPiSessionPath(sessionPath, errorMessage);
#endif
}

bool RouteMappingPiPhotoFetcher::_sendRemoteUdpCommand(const QString &command) const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(command);
    return false;
#else
    if (_piHost.isEmpty()) {
        return false;
    }

    // Never run ssh synchronously here. This method is called from QML on the
    // GUI thread for every shot; the old ssh+nc path stalled that thread for a
    // second and then sent the same command again over UDP.
    QUdpSocket socket;
    const QByteArray payload = command.toUtf8();
    const qint64 sent = socket.writeDatagram(payload, QHostAddress(_piHost), static_cast<quint16>(_piTriggerPort));
    if (sent == payload.size()) {
        qCInfo(RouteMappingPiPhotoFetcherLog) << "Sent UDP" << command << "to" << _piHost << _piTriggerPort;
        return true;
    }
    qCWarning(RouteMappingPiPhotoFetcherLog) << "Failed to send UDP" << command << socket.errorString();
    return false;
#endif
}

bool RouteMappingPiPhotoFetcher::_requestRemoteUdpCommand(
    const QString &command,
    QString *response,
    QString *errorMessage,
    int timeoutMs,
    const QRegularExpression *acceptableReply) const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(command);
    Q_UNUSED(response);
    Q_UNUSED(timeoutMs);
    Q_UNUSED(acceptableReply);
    if (errorMessage) {
        *errorMessage = tr("Pi UDP session control is not supported on Windows");
    }
    return false;
#else
    QUdpSocket socket;
    if (!socket.bind(QHostAddress::AnyIPv4, 0)) {
        if (errorMessage) {
            *errorMessage = socket.errorString();
        }
        return false;
    }

    while (socket.hasPendingDatagrams()) {
        QByteArray stale;
        stale.resize(static_cast<int>(socket.pendingDatagramSize()));
        socket.readDatagram(stale.data(), stale.size());
    }

    const QByteArray payload = command.toUtf8();
    if (socket.writeDatagram(payload, QHostAddress(_piHost), static_cast<quint16>(_piTriggerPort)) != payload.size()) {
        if (errorMessage) {
            *errorMessage = socket.errorString();
        }
        return false;
    }

    QString lastReply;
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < timeoutMs) {
        const int remaining = timeoutMs - static_cast<int>(timer.elapsed());
        if (!socket.waitForReadyRead(qMax(remaining, 1))) {
            break;
        }

        while (socket.hasPendingDatagrams()) {
            QByteArray datagram;
            datagram.resize(static_cast<int>(socket.pendingDatagramSize()));
            if (socket.readDatagram(datagram.data(), datagram.size()) < 0) {
                continue;
            }
            const QString reply = QString::fromUtf8(datagram).trimmed();
            lastReply = reply;
            if (acceptableReply == nullptr) {
                if (response) {
                    *response = reply;
                }
                return true;
            }
            if (acceptableReply->match(reply).hasMatch()) {
                if (response) {
                    *response = reply;
                }
                return true;
            }
            qCInfo(RouteMappingPiPhotoFetcherLog)
                << "Ignoring Pi UDP reply while waiting for" << command << "response:" << reply;
        }
    }

    if (errorMessage) {
        if (!lastReply.isEmpty() && acceptableReply != nullptr) {
            *errorMessage = tr("Unexpected Pi %1 reply: %2").arg(command, lastReply);
        } else {
            *errorMessage = tr("Timed out waiting for the Pi %1 reply").arg(command);
        }
    }
    return false;
#endif
}

bool RouteMappingPiPhotoFetcher::pauseLiveVideo()
{
    return beginSession();
}

bool RouteMappingPiPhotoFetcher::resumeLiveVideo()
{
    if (!_enabled) {
        return false;
    }
    const bool ok = _sendRemoteUdpCommand(QStringLiteral("VIDEO_RESUME"));
    if (ok) {
        qCInfo(RouteMappingPiPhotoFetcherLog) << "Requested Pi live video resume after route mapping stills";
        if (!_piSessionPath.isEmpty()) {
            _piSessionPath.clear();
            emit piSessionPathChanged();
        }
    }
    return ok;
}

bool RouteMappingPiPhotoFetcher::_parseCaptureUdpResponse(
    int sequence, const QString &response, QString *remotePhotoPath, QString *remoteThumbnailPath) const
{
    QString trimmed = response.trimmed();
    if (trimmed.length() >= 2
        && ((trimmed.startsWith(QLatin1Char('"')) && trimmed.endsWith(QLatin1Char('"')))
            || (trimmed.startsWith(QLatin1Char('\'')) && trimmed.endsWith(QLatin1Char('\''))))) {
        trimmed = trimmed.mid(1, trimmed.length() - 2).trimmed();
    }
    const QString photoRoot = QDir::cleanPath(_piPhotoRoot);

    static const QRegularExpression queuedWithPath(
        QStringLiteral("^QUEUED\\s+seq=(\\d+)\\s+path=(/[^\\s]+)(?:\\s+thumb=(/[^\\s]+))?$"),
        QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression queuedPlain(QStringLiteral("^QUEUED$"));
    static const QRegularExpression queuedWithSeqOnly(
        QStringLiteral("^QUEUED\\s+seq=(\\d+)$"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression bareGcsImagePath(
        QStringLiteral("^(/[^\\s]+/image_(\\d{4})_gcs_\\d{4}_[^\\s]+\\.jpg)$"),
        QRegularExpression::CaseInsensitiveOption);

    const QRegularExpressionMatch pathMatch = queuedWithPath.match(trimmed);
    if (pathMatch.hasMatch()) {
        const int ackSequence = pathMatch.captured(1).toInt();
        if (!applyCaptureAckPaths(
                sequence,
                ackSequence,
                photoRoot,
                pathMatch.captured(2),
                pathMatch.captured(3),
                remotePhotoPath,
                remoteThumbnailPath)) {
            qCWarning(RouteMappingPiPhotoFetcherLog)
                << "CAPTURE ack rejected for sequence" << sequence << "reply" << trimmed;
            return false;
        }
        qCInfo(RouteMappingPiPhotoFetcherLog)
            << "Trigger queued sequence" << sequence << "path" << pathMatch.captured(2)
            << "thumb" << (remoteThumbnailPath ? remoteThumbnailPath->trimmed() : QString())
            << "(QUEUED path=)";
        return true;
    }

    const QRegularExpressionMatch bareMatch = bareGcsImagePath.match(trimmed);
    if (bareMatch.hasMatch()) {
        const int ackSequence = bareMatch.captured(2).toInt();
        if (!applyCaptureAckPaths(
                sequence,
                ackSequence,
                photoRoot,
                bareMatch.captured(1),
                {},
                remotePhotoPath,
                remoteThumbnailPath)) {
            qCWarning(RouteMappingPiPhotoFetcherLog)
                << "CAPTURE bare path rejected for sequence" << sequence << "reply" << trimmed;
            return false;
        }
        qCInfo(RouteMappingPiPhotoFetcherLog)
            << "Trigger queued sequence" << sequence << "path" << bareMatch.captured(1)
            << "thumb" << (remoteThumbnailPath ? remoteThumbnailPath->trimmed() : QString())
            << "(bare path)";
        return true;
    }

    const QRegularExpressionMatch seqOnlyMatch = queuedWithSeqOnly.match(trimmed);
    if (seqOnlyMatch.hasMatch()) {
        const int ackSequence = seqOnlyMatch.captured(1).toInt();
        if (ackSequence != sequence) {
            qCWarning(RouteMappingPiPhotoFetcherLog)
                << "CAPTURE ack sequence mismatch: expected" << sequence << "got" << ackSequence;
            return false;
        }
        qCInfo(RouteMappingPiPhotoFetcherLog)
            << "Trigger queued sequence" << sequence << "(Pi reply without path; will use session-scoped find)";
        return true;
    }

    if (queuedPlain.match(trimmed).hasMatch()) {
        qCInfo(RouteMappingPiPhotoFetcherLog)
            << "Trigger queued sequence" << sequence << "(legacy Pi reply; will use session-scoped find)";
        return true;
    }

    if (trimmed.compare(QStringLiteral("BUSY"), Qt::CaseInsensitive) == 0) {
        qCWarning(RouteMappingPiPhotoFetcherLog) << "Pi capture queue busy for sequence" << sequence;
        return false;
    }

    qCWarning(RouteMappingPiPhotoFetcherLog) << "Unexpected CAPTURE response:" << trimmed;
    return false;
}

bool RouteMappingPiPhotoFetcher::triggerCapture(
    int sequence, QString *remotePhotoPath, QString *remoteThumbnailPath)
{
    if (!_enabled || !_acceptingCaptures) {
        return false;
    }
    if (_piHost.isEmpty() || sequence < 1 || _piSessionPath.isEmpty()) {
        return false;
    }

    QString sshError;
    if (_triggerCaptureViaSsh(sequence, remotePhotoPath, remoteThumbnailPath, &sshError)) {
        return true;
    }
    qCInfo(RouteMappingPiPhotoFetcherLog)
        << "SSH CAPTURE" << sequence << "failed; falling back to UDP:" << sshError;

    QString response;
    QString errorMessage;
    for (int attempt = 0; attempt < kCaptureUdpAckAttempts; ++attempt) {
        if (_requestRemoteUdpCommand(
                QStringLiteral("CAPTURE %1").arg(sequence),
                &response,
                &errorMessage,
                kCaptureUdpAckTimeoutMs,
                &kCaptureUdpAcceptableReply)) {
            return _parseCaptureUdpResponse(sequence, response, remotePhotoPath, remoteThumbnailPath);
        }
        qCDebug(RouteMappingPiPhotoFetcherLog)
            << "CAPTURE" << sequence << "UDP ack not received:" << errorMessage;
    }

    // WFB often drops the Pi→GCS reply while the command still reaches the Pi.
    if (_sendRemoteUdpCommand(QStringLiteral("CAPTURE %1").arg(sequence))) {
        qCInfo(RouteMappingPiPhotoFetcherLog)
            << "CAPTURE" << sequence
            << "sent over UDP without ack — SCP retries will wait for the JPEG";
        if (remotePhotoPath) {
            remotePhotoPath->clear();
        }
        if (remoteThumbnailPath) {
            remoteThumbnailPath->clear();
        }
        return true;
    }

    return false;
}

void RouteMappingPiPhotoFetcher::triggerCaptureQueued(int sequence)
{
    RouteMappingPiPhotoFetcher *const self = this;
    (void)QtConcurrent::run([self, sequence]() {
        QString remotePhotoPath;
        QString remoteThumbnailPath;
        const bool success = self->triggerCapture(sequence, &remotePhotoPath, &remoteThumbnailPath);
        const QString pathForMain = remotePhotoPath;
        const QString thumbForMain = remoteThumbnailPath;
        QMetaObject::invokeMethod(
            self,
            [self, sequence, success, pathForMain, thumbForMain]() {
                emit self->triggerCaptureFinished(sequence, success, pathForMain, thumbForMain);
            },
            Qt::QueuedConnection);
    });
}

void RouteMappingPiPhotoFetcher::fetchLatestPhoto(const QString &localFilePath, int requestId)
{
    fetchPhotoBySequence(0, localFilePath, requestId);
}

void RouteMappingPiPhotoFetcher::fetchPhotoBySequence(
    int sequence,
    const QString &localFilePath,
    int requestId,
    const QString &remotePhotoPath,
    const QString &remoteThumbnailPath)
{
    if (!_enabled) {
        emit photoFetched(requestId, localFilePath, false, tr("Pi photo fetch is disabled"));
        return;
    }

    if (_piHost.isEmpty() || _piUser.isEmpty() || _piPhotoRoot.isEmpty()) {
        emit photoFetched(requestId, localFilePath, false, tr("Pi photo fetch settings are incomplete"));
        return;
    }

    if (localFilePath.trimmed().isEmpty()) {
        emit photoFetched(requestId, localFilePath, false, tr("Local photo path is empty"));
        return;
    }

#if defined(Q_OS_WIN)
    Q_UNUSED(sequence);
    emit photoFetched(requestId, localFilePath, false, tr("Pi SSH photo fetch is not supported on Windows"));
    return;
#else
    FetchRequest request;
    request.requestId = requestId;
    request.localFilePath = localFilePath;
    request.attempt = 0;
    request.photoSequence = sequence;
    request.bySequence = sequence > 0;
    request.generation = _generation;
    request.remoteSessionPath = _piSessionPath;
    request.remotePhotoPath = QDir::cleanPath(remotePhotoPath.trimmed());
    request.remoteThumbnailPath = QDir::cleanPath(remoteThumbnailPath.trimmed());
    _queue.append(request);
    emit pendingFetchCountChanged();
    _startNextFetch();
#endif
}

int RouteMappingPiPhotoFetcher::_indexOfFetchRequest(int requestId) const
{
    for (int index = 0; index < _queue.size(); ++index) {
        if (_queue.at(index).requestId == requestId) {
            return index;
        }
    }
    return -1;
}

void RouteMappingPiPhotoFetcher::_beginFetchTransfer(FetchRequest request)
{
    if (request.generation != _generation) {
        return;
    }

    if (request.fullResInFlight) {
        return;
    }

    if (!request.remoteThumbnailPath.isEmpty() && !request.thumbFetched) {
        _downloadRemotePhoto(request, request.remoteThumbnailPath, true);
        return;
    }

    if (!request.remotePhotoPath.isEmpty()) {
        _downloadRemotePhoto(request, request.remotePhotoPath, false);
        return;
    }
    _listRemotePhotos(request);
}

void RouteMappingPiPhotoFetcher::_startNextFetch()
{
    if (_queue.isEmpty()) {
        return;
    }

    while (_activeFetchCount < kMaxConcurrentFetches) {
        int startIndex = -1;
        // Always display every available preview before spending the slow
        // radio link on another full-resolution JPEG.
        for (int index = 0; index < _queue.size(); ++index) {
            const FetchRequest &candidate = _queue.at(index);
            if (candidate.fullResInFlight || candidate.transferStarted) {
                continue;
            }
            if (!candidate.remoteThumbnailPath.isEmpty() && !candidate.thumbFetched) {
                startIndex = index;
                break;
            }
        }
        if (startIndex < 0) {
            if (_activeFetchCount > 0) {
                return;
            }
            for (int index = 0; index < _queue.size(); ++index) {
                const FetchRequest &candidate = _queue.at(index);
                if (!candidate.fullResInFlight && !candidate.transferStarted) {
                    startIndex = index;
                    break;
                }
            }
        }
        if (startIndex < 0) {
            return;
        }

        _queue[startIndex].transferStarted = true;
        _activeFetchCount++;
        _beginFetchTransfer(_queue.at(startIndex));
    }
}

void RouteMappingPiPhotoFetcher::_listRemotePhotos(FetchRequest request)
{
    if (request.generation != _generation) {
        _activeFetchCount = qMax(0, _activeFetchCount - 1);
        _startNextFetch();
        return;
    }

    QProcess *process = new QProcess(this);
    process->setProgram(QStringLiteral("ssh"));
    QStringList arguments = _baseSshOptions();

    const QString findRoot = !request.remoteSessionPath.isEmpty()
        ? request.remoteSessionPath
        : QDir::cleanPath(_piPhotoRoot);

    QString remoteScript;
    if (request.bySequence) {
        const QString seqToken = QStringLiteral("image_%1_")
                                         .arg(request.photoSequence, 4, 10, QChar('0'));
        remoteScript = QStringLiteral(
                           "find %1 -type f -name %2 ! -name '*.part.jpg' 2>/dev/null | sort | tail -1")
                           .arg(shellQuote(findRoot), shellQuote(seqToken + QStringLiteral("*.jpg")));
    } else {
        remoteScript = QStringLiteral(
                           "find %1 -type f -name 'image_*.jpg' ! -name '*.part.jpg' 2>/dev/null | sort")
                           .arg(shellQuote(findRoot));
    }
    arguments << _sshTarget() << remoteScript;
    process->setArguments(arguments);

    const auto handled = std::make_shared<bool>(false);
    const auto handleFinished = [this, request, process, handled, findRoot](int exitCode, QProcess::ExitStatus exitStatus) {
        if (*handled) {
            return;
        }
        *handled = true;
        const QString stdoutText = trimmedProcessOutput(*process);
        const QString stderrText = trimmedProcessError(*process);
        process->deleteLater();

        if (request.generation != _generation) {
            return;
        }

        if (exitStatus != QProcess::NormalExit || exitCode != 0) {
            qCWarning(RouteMappingPiPhotoFetcherLog) << "Remote photo listing failed:" << stderrText;
            _scheduleRetry(request);
            return;
        }

        QString remotePath;
        const QStringList lines = stdoutText.split('\n', Qt::SkipEmptyParts);
        if (request.bySequence) {
            remotePath = stdoutText.trimmed();
        } else {
            for (int index = lines.size() - 1; index >= 0; --index) {
                const QString candidate = lines.at(index).trimmed();
                if (candidate.isEmpty() || _downloadedRemotePaths.contains(candidate)) {
                    continue;
                }
                remotePath = candidate;
                break;
            }
        }

        const QString expectedDirectory = findRoot + QLatin1Char('/');
        if (!remotePath.startsWith(expectedDirectory) || remotePath.contains(QLatin1Char('\n'))) {
            qCWarning(RouteMappingPiPhotoFetcherLog) << "Invalid remote photo path from find:" << remotePath
                                                     << "stdout:" << stdoutText;
            _scheduleRetry(request);
            return;
        }

        if (remotePath.isEmpty() || _downloadedRemotePaths.contains(remotePath)) {
            _scheduleRetry(request);
            return;
        }

        _downloadRemotePhoto(request, remotePath);
    };
    connect(process, &QProcess::finished, this, handleFinished);
    connect(process, &QProcess::errorOccurred, this,
            [handleFinished](QProcess::ProcessError error) mutable {
                if (error == QProcess::FailedToStart) {
                    handleFinished(-1, QProcess::CrashExit);
                }
            });

    process->start();
    QTimer::singleShot(kProcessTimeoutMs, process, [process]() {
        if (process->state() != QProcess::NotRunning) {
            process->kill();
        }
    });
}

bool RouteMappingPiPhotoFetcher::_scpRemotePhotoToLocal(
    const FetchRequest &request,
    const QString &remotePath,
    const QString &localFilePath,
    bool thumbnailTier,
    QString *errorMessage) const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(request);
    Q_UNUSED(remotePath);
    Q_UNUSED(localFilePath);
    Q_UNUSED(thumbnailTier);
    if (errorMessage) {
        *errorMessage = tr("Pi SSH photo fetch is not supported on Windows");
    }
    return false;
#else
    const QString cleanedPath = QDir::cleanPath(remotePath);
    const QString photoRoot = QDir::cleanPath(_piPhotoRoot);
    const QString sessionPrefix = request.remoteSessionPath.isEmpty()
        ? QString()
        : QDir::cleanPath(request.remoteSessionPath) + QLatin1Char('/');
    if (!cleanedPath.startsWith(photoRoot + QLatin1Char('/'))
        || cleanedPath.contains(QLatin1Char('\n'))
        || (!sessionPrefix.isEmpty() && !cleanedPath.startsWith(sessionPrefix))) {
        if (errorMessage) {
            *errorMessage = tr("Refusing remote photo path: %1").arg(cleanedPath);
        }
        return false;
    }

    const QFileInfo localInfo(localFilePath);
    QDir().mkpath(localInfo.absolutePath());

    const QString temporaryPath = localFilePath + QStringLiteral(".part");
    QFile::remove(temporaryPath);

    QProcess process;
    process.setProgram(QStringLiteral("scp"));
    QStringList arguments = _baseSshOptions();
    arguments << QStringLiteral("%1:%2").arg(_sshTarget(), cleanedPath) << temporaryPath;
    process.setArguments(arguments);

    if (!runProcess(process, kProcessTimeoutMs, errorMessage)) {
        QFile::remove(temporaryPath);
        return false;
    }

    const QFileInfo downloadedInfo(temporaryPath);
    const int minimumBytes = thumbnailTier ? 1024 : kMinDownloadedJpegBytes;
    if (!downloadedInfo.isFile() || downloadedInfo.size() < minimumBytes) {
        QFile::remove(temporaryPath);
        if (errorMessage) {
            *errorMessage = tr("Downloaded image is too small or missing");
        }
        return false;
    }

    QImageReader reader(temporaryPath);
    if (!reader.canRead() || !reader.size().isValid()) {
        QFile::remove(temporaryPath);
        if (errorMessage) {
            *errorMessage = tr("Downloaded file is not a valid image");
        }
        return false;
    }

    QFile::remove(localFilePath);
    if (!QFile::rename(temporaryPath, localFilePath)) {
        QFile::remove(temporaryPath);
        if (errorMessage) {
            *errorMessage = tr("Could not publish downloaded image");
        }
        return false;
    }

    return true;
#endif
}

int RouteMappingPiPhotoFetcher::_indexOfDeferredFullResRequest(int requestId) const
{
    for (int index = 0; index < _deferredFullResQueue.size(); ++index) {
        if (_deferredFullResQueue.at(index).requestId == requestId) {
            return index;
        }
    }
    return -1;
}

void RouteMappingPiPhotoFetcher::_deferFullResAfterThumb(FetchRequest request)
{
    if (request.generation != _generation) {
        return;
    }

    const int index = _indexOfFetchRequest(request.requestId);
    if (index >= 0) {
        _queue.removeAt(index);
    }
    _activeFetchCount = qMax(0, _activeFetchCount - 1);

    if (request.remotePhotoPath.isEmpty()) {
        emit pendingFetchCountChanged();
        _tryCompleteSessionEnd();
        _startNextFetch();
        return;
    }

    request.thumbFetched = true;
    request.transferStarted = false;
    request.fullResInFlight = false;
    request.attempt = 0;
    _deferredFullResQueue.append(request);
    emit pendingFetchCountChanged();
    _tryCompleteSessionEnd();
    _startNextFetch();
}

void RouteMappingPiPhotoFetcher::_tryCompleteSessionEnd()
{
    if (_acceptingCaptures || !_queue.isEmpty() || _activeFetchCount > 0) {
        return;
    }

    if (!_liveFetchQueueDrainedEmitted) {
        _liveFetchQueueDrainedEmitted = true;
        qCInfo(RouteMappingPiPhotoFetcherLog)
            << "In-flight thumb SCP queue drained;"
            << _deferredFullResQueue.size() << "full-res archive(s) deferred until after disarm";
        emit fetchQueueDrained();
    }

    _pumpDeferredFullResDrain();
}

void RouteMappingPiPhotoFetcher::_pumpDeferredFullResDrain()
{
    if (!_liveFetchQueueDrainedEmitted) {
        return;
    }

    while (_deferredFullResActiveCount < kMaxConcurrentFullResDrain) {
        int startIndex = -1;
        for (int index = 0; index < _deferredFullResQueue.size(); ++index) {
            if (!_deferredFullResQueue.at(index).fullResInFlight) {
                startIndex = index;
                break;
            }
        }
        if (startIndex < 0) {
            return;
        }

        FetchRequest request = _deferredFullResQueue.at(startIndex);
        request.fullResInFlight = true;
        _deferredFullResQueue[startIndex] = request;
        _deferredFullResActiveCount++;
        _runDeferredFullResJob(request);
    }
}

void RouteMappingPiPhotoFetcher::_runDeferredFullResJob(FetchRequest request)
{
    if (request.generation != _generation || request.remotePhotoPath.isEmpty()) {
        _deferredFullResActiveCount = qMax(0, _deferredFullResActiveCount - 1);
        _pumpDeferredFullResDrain();
        return;
    }

    RouteMappingPiPhotoFetcher *const self = this;
    const quint64 generation = request.generation;
    const FetchRequest backgroundRequest = request;

    (void)QtConcurrent::run([self, backgroundRequest, generation]() {
        QString errorMessage;
        const bool success = self->_scpRemotePhotoToLocal(
            backgroundRequest,
            backgroundRequest.remotePhotoPath,
            backgroundRequest.localFilePath,
            false,
            &errorMessage);

        const QString errorForMain = errorMessage;
        QMetaObject::invokeMethod(
            self,
            [self, backgroundRequest, generation, success, errorForMain]() {
                if (generation != self->_generation) {
                    const int staleIndex = self->_indexOfDeferredFullResRequest(backgroundRequest.requestId);
                    if (staleIndex >= 0) {
                        self->_deferredFullResQueue.removeAt(staleIndex);
                        emit self->pendingFetchCountChanged();
                    }
                    self->_deferredFullResActiveCount = qMax(0, self->_deferredFullResActiveCount - 1);
                    self->_pumpDeferredFullResDrain();
                    return;
                }
                self->_completeDeferredFullRes(backgroundRequest, success, errorForMain);
            },
            Qt::QueuedConnection);
    });
}

void RouteMappingPiPhotoFetcher::_completeDeferredFullRes(
    FetchRequest request, bool success, const QString &errorMessage)
{
    if (request.generation != _generation) {
        _deferredFullResActiveCount = qMax(0, _deferredFullResActiveCount - 1);
        _pumpDeferredFullResDrain();
        return;
    }

    const int index = _indexOfDeferredFullResRequest(request.requestId);
    if (index < 0) {
        _deferredFullResActiveCount = qMax(0, _deferredFullResActiveCount - 1);
        _pumpDeferredFullResDrain();
        return;
    }

    request = _deferredFullResQueue.at(index);
    request.fullResInFlight = false;
    _deferredFullResActiveCount = qMax(0, _deferredFullResActiveCount - 1);

    if (success) {
        _downloadedRemotePaths.insert(QDir::cleanPath(request.remotePhotoPath));
        _deferredFullResQueue.removeAt(index);
        emit pendingFetchCountChanged();
        qCInfo(RouteMappingPiPhotoFetcherLog)
            << "Fetched full-res archive" << request.remotePhotoPath << "to" << request.localFilePath;
        emit photoFullFetched(request.requestId, request.localFilePath, true, {});
        _pumpDeferredFullResDrain();
        return;
    }

    request.attempt++;
    if (request.attempt >= kMaxFetchAttempts) {
        _deferredFullResQueue.removeAt(index);
        emit pendingFetchCountChanged();
        emit photoFullFetched(request.requestId, request.localFilePath, false, errorMessage);
        _pumpDeferredFullResDrain();
        return;
    }

    qCWarning(RouteMappingPiPhotoFetcherLog)
        << "Deferred full-res SCP failed for" << request.remotePhotoPath << errorMessage;
    _deferredFullResQueue[index] = request;
    const quint64 generation = request.generation;
    const int requestId = request.requestId;
    QTimer::singleShot(kRetryDelayPlannedPathMs, this, [this, generation, requestId]() {
        if (generation != _generation) {
            return;
        }
        _pumpDeferredFullResDrain();
    });
    _pumpDeferredFullResDrain();
}

void RouteMappingPiPhotoFetcher::_downloadRemotePhoto(
    FetchRequest request, const QString &remotePath, bool thumbnailTier)
{
    const QString cleanedPath = QDir::cleanPath(remotePath);
    const QString photoRoot = QDir::cleanPath(_piPhotoRoot);
    const QString sessionPrefix = request.remoteSessionPath.isEmpty()
        ? QString()
        : QDir::cleanPath(request.remoteSessionPath) + QLatin1Char('/');
    if (!cleanedPath.startsWith(photoRoot + QLatin1Char('/'))
        || cleanedPath.contains(QLatin1Char('\n'))
        || (!sessionPrefix.isEmpty() && !cleanedPath.startsWith(sessionPrefix))) {
        qCWarning(RouteMappingPiPhotoFetcherLog) << "Refusing remote photo path:" << cleanedPath;
        _scheduleRetry(request);
        return;
    }

    const QFileInfo localInfo(request.localFilePath);
    QDir().mkpath(localInfo.absolutePath());

    const QString temporaryPath = request.localFilePath + QStringLiteral(".part");
    QFile::remove(temporaryPath);

    QProcess *process = new QProcess(this);
    process->setProgram(QStringLiteral("scp"));
    QStringList arguments = _baseSshOptions();
    arguments << QStringLiteral("%1:%2").arg(_sshTarget(), cleanedPath) << temporaryPath;
    process->setArguments(arguments);

    const auto handled = std::make_shared<bool>(false);
    const auto handleFinished = [this, request, cleanedPath, thumbnailTier, process, handled](
                                    int exitCode, QProcess::ExitStatus exitStatus) {
        if (*handled) {
            return;
        }
        *handled = true;
        const QString stderrText = trimmedProcessError(*process);
        process->deleteLater();

        if (request.generation != _generation) {
            QFile::remove(request.localFilePath + QStringLiteral(".part"));
            return;
        }

        if (exitStatus != QProcess::NormalExit || exitCode != 0) {
            if (remoteScpTargetMissing(stderrText)) {
                qCInfo(RouteMappingPiPhotoFetcherLog)
                    << "Pi photo not written yet (will retry SCP):" << cleanedPath;
                if (thumbnailTier && request.attempt >= 6 && !request.remotePhotoPath.isEmpty()) {
                    FetchRequest fullRequest = request;
                    fullRequest.remoteThumbnailPath.clear();
                    fullRequest.thumbFetched = true;
                    const int index = _indexOfFetchRequest(request.requestId);
                    if (index >= 0) {
                        _queue[index] = fullRequest;
                    }
                    _activeFetchCount = qMax(0, _activeFetchCount - 1);
                    _beginFetchTransfer(fullRequest);
                    _startNextFetch();
                    return;
                }
                _scheduleRetry(request, kRetryDelayRemoteMissingMs);
            } else {
                qCWarning(RouteMappingPiPhotoFetcherLog) << "SCP failed for" << cleanedPath << stderrText;
                _scheduleRetry(request);
            }
            return;
        }

        const QString temporaryPath = request.localFilePath + QStringLiteral(".part");
        const QFileInfo localInfo(temporaryPath);
        const int minimumBytes = thumbnailTier ? 1024 : kMinDownloadedJpegBytes;
        if (!localInfo.isFile() || localInfo.size() < minimumBytes) {
            if (localInfo.isFile() && localInfo.size() > 0) {
                qCInfo(RouteMappingPiPhotoFetcherLog)
                    << "Downloaded image still too small (Pi may still be writing)"
                    << temporaryPath << localInfo.size() << "bytes";
            }
            QFile::remove(temporaryPath);
            _scheduleRetry(request);
            return;
        }

        QImageReader reader(temporaryPath);
        if (!reader.canRead() || !reader.size().isValid()) {
            qCWarning(RouteMappingPiPhotoFetcherLog) << "Downloaded file is not a valid image" << temporaryPath;
            QFile::remove(temporaryPath);
            _scheduleRetry(request);
            return;
        }

        QFile::remove(request.localFilePath);
        if (!QFile::rename(temporaryPath, request.localFilePath)) {
            qCWarning(RouteMappingPiPhotoFetcherLog) << "Could not publish downloaded image" << request.localFilePath;
            _scheduleRetry(request);
            return;
        }

        qCInfo(RouteMappingPiPhotoFetcherLog)
            << (thumbnailTier ? "Fetched thumbnail" : "Fetched")
            << cleanedPath << "to" << request.localFilePath;
        if (thumbnailTier) {
            emit photoFetched(request.requestId, request.localFilePath, true, {});
            FetchRequest deferredRequest = request;
            deferredRequest.thumbFetched = true;
            deferredRequest.transferStarted = false;
            _deferFullResAfterThumb(deferredRequest);
            return;
        }

        _downloadedRemotePaths.insert(cleanedPath);
        _finishFetch(request, true, {}, true);
    };
    connect(process, &QProcess::finished, this, handleFinished);
    connect(process, &QProcess::errorOccurred, this,
            [handleFinished](QProcess::ProcessError error) mutable {
                if (error == QProcess::FailedToStart) {
                    handleFinished(-1, QProcess::CrashExit);
                }
            });

    process->start();
    QTimer::singleShot(kProcessTimeoutMs, process, [process]() {
        if (process->state() != QProcess::NotRunning) {
            process->kill();
        }
    });
}

void RouteMappingPiPhotoFetcher::_scheduleRetry(FetchRequest request, int retryDelayOverrideMs)
{
    if (request.generation != _generation) {
        return;
    }

    request.attempt++;
    if (request.attempt >= kMaxFetchAttempts) {
        const QString timeoutMessage = tr("Timed out waiting for Pi mapping photo");
        if (request.thumbFetched && !request.remoteThumbnailPath.isEmpty()) {
            emit photoFullFetched(request.requestId, request.localFilePath, false, timeoutMessage);
            _finishFetch(request, false, timeoutMessage, false);
        } else {
            _finishFetch(request, false, timeoutMessage);
        }
        return;
    }

    const int queueIndex = _indexOfFetchRequest(request.requestId);
    if (queueIndex < 0) {
        _activeFetchCount = qMax(0, _activeFetchCount - 1);
        _startNextFetch();
        return;
    }

    request.transferStarted = false;
    _queue[queueIndex] = request;
    _activeFetchCount = qMax(0, _activeFetchCount - 1);

    // Re-send CAPTURE only when we do not know the remote path (legacy find flow).
    if (request.remotePhotoPath.isEmpty() && request.bySequence && request.attempt % 5 == 0) {
        (void)_sendRemoteUdpCommand(QStringLiteral("CAPTURE %1").arg(request.photoSequence));
    }

    const quint64 generation = request.generation;
    const int requestId = request.requestId;
    int retryDelayMs = retryDelayOverrideMs;
    if (retryDelayMs < 0) {
        if (!request.remotePhotoPath.isEmpty()) {
            retryDelayMs = kRetryDelayPlannedPathMs;
        } else {
            retryDelayMs = request.attempt <= kFastRetryAttempts ? kRetryDelayFirstMs : kRetryDelayMs;
        }
    }
    QTimer::singleShot(retryDelayMs, this, [this, generation, requestId]() {
        if (generation != _generation) {
            return;
        }
        const int index = _indexOfFetchRequest(requestId);
        if (index < 0) {
            return;
        }
        FetchRequest retryRequest = _queue.at(index);
        if (retryRequest.transferStarted) {
            return;
        }
        retryRequest.transferStarted = true;
        _queue[index] = retryRequest;
        _activeFetchCount++;
        _beginFetchTransfer(retryRequest);
    });
}

void RouteMappingPiPhotoFetcher::_finishFetch(
    const FetchRequest &request, bool success, const QString &errorMessage, bool emitPhotoFetched)
{
    if (request.generation != _generation) {
        return;
    }

    if (emitPhotoFetched) {
        emit photoFetched(request.requestId, request.localFilePath, success, errorMessage);
    }

    const int index = _indexOfFetchRequest(request.requestId);
    if (index >= 0) {
        _queue.removeAt(index);
        emit pendingFetchCountChanged();
    }
    _activeFetchCount = qMax(0, _activeFetchCount - 1);
    _tryCompleteSessionEnd();
    _startNextFetch();
}
