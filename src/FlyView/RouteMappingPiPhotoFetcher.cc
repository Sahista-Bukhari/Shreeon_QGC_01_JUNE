#include "RouteMappingPiPhotoFetcher.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QProcess>
#include <QtCore/QTimer>
#include <QtNetwork/QHostAddress>
#include <QtNetwork/QUdpSocket>

QGC_LOGGING_CATEGORY(RouteMappingPiPhotoFetcherLog, "FlyView.RouteMappingPiPhotoFetcher")

namespace {
constexpr int kMaxFetchAttempts = 20;
constexpr int kRetryDelayMs = 2000;
constexpr int kProcessTimeoutMs = 30000;

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
            *errorMessage = stderrText.isEmpty()
                                  ? QObject::tr("%1 failed with exit code %2")
                                        .arg(process.program())
                                        .arg(process.exitCode())
                                  : stderrText;
        }
        return false;
    }

    return true;
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

void RouteMappingPiPhotoFetcher::resetSession()
{
    _downloadedRemotePaths.clear();
    _queue.clear();
    _busy = false;
    _acceptingCaptures = true;
}

void RouteMappingPiPhotoFetcher::cancelSession()
{
    _acceptingCaptures = false;
    _queue.clear();
    _busy = false;
}

QString RouteMappingPiPhotoFetcher::_sshTarget() const
{
    return QStringLiteral("%1@%2").arg(_piUser, _piHost);
}

QStringList RouteMappingPiPhotoFetcher::_baseSshOptions()
{
    return {
        QStringLiteral("-o"),
        QStringLiteral("BatchMode=yes"),
        QStringLiteral("-o"),
        QStringLiteral("ConnectTimeout=5"),
        QStringLiteral("-o"),
        QStringLiteral("StrictHostKeyChecking=accept-new"),
    };
}

bool RouteMappingPiPhotoFetcher::testConnection() const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(this);
    return false;
#else
    if (_piHost.isEmpty() || _piUser.isEmpty()) {
        return false;
    }

    QProcess process;
    process.setProgram(QStringLiteral("ssh"));
    QStringList arguments = _baseSshOptions();
    arguments << _sshTarget() << QStringLiteral("echo OK");
    process.setArguments(arguments);

    QString errorMessage;
    if (!runProcess(process, kProcessTimeoutMs, &errorMessage)) {
        qCWarning(RouteMappingPiPhotoFetcherLog) << "SSH test failed:" << errorMessage;
        return false;
    }

    return trimmedProcessOutput(process).compare(QStringLiteral("OK"), Qt::CaseInsensitive) == 0;
#endif
}

bool RouteMappingPiPhotoFetcher::_sendRemoteUdpCommand(const QString &command, const QString &successToken) const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(command);
    Q_UNUSED(successToken);
    return false;
#else
    if (_piHost.isEmpty() || _piUser.isEmpty()) {
        return false;
    }

    bool ok = false;

    QProcess sshProcess;
    sshProcess.setProgram(QStringLiteral("ssh"));
    const QString remoteCommand = QStringLiteral("printf '%1' | nc -u -w1 127.0.0.1 %2")
                                      .arg(command)
                                      .arg(_piTriggerPort);
    QStringList sshArguments = _baseSshOptions();
    sshArguments << _sshTarget() << remoteCommand;
    sshProcess.setArguments(sshArguments);

    QString sshError;
    if (runProcess(sshProcess, kProcessTimeoutMs, &sshError)) {
        const QString response = trimmedProcessOutput(sshProcess);
        ok = response.contains(successToken, Qt::CaseInsensitive);
        if (!ok) {
            qCWarning(RouteMappingPiPhotoFetcherLog) << command << "SSH unexpected response:" << response;
        }
    } else {
        const QString sshStderr = trimmedProcessError(sshProcess);
        qCWarning(RouteMappingPiPhotoFetcherLog) << command << "SSH failed:" << sshError
                                                 << sshStderr;
    }

    QUdpSocket socket;
    const QByteArray payload = command.toUtf8();
    const qint64 sent = socket.writeDatagram(payload, QHostAddress(_piHost), static_cast<quint16>(_piTriggerPort));
    if (sent == payload.size()) {
        qCInfo(RouteMappingPiPhotoFetcherLog) << "Sent UDP" << command << "to" << _piHost << _piTriggerPort;
        ok = true;
    }

    return ok;
#endif
}

bool RouteMappingPiPhotoFetcher::pauseLiveVideo()
{
    if (!_enabled) {
        return false;
    }
    const bool ok = _sendRemoteUdpCommand(QStringLiteral("VIDEO_PAUSE"), QStringLiteral("OK"));
    if (ok) {
        qCInfo(RouteMappingPiPhotoFetcherLog) << "Requested Pi live video pause for route mapping stills";
    }
    return ok;
}

bool RouteMappingPiPhotoFetcher::resumeLiveVideo()
{
    if (!_enabled) {
        return false;
    }
    const bool ok = _sendRemoteUdpCommand(QStringLiteral("VIDEO_RESUME"), QStringLiteral("OK"));
    if (ok) {
        qCInfo(RouteMappingPiPhotoFetcherLog) << "Requested Pi live video resume after route mapping stills";
    }
    return ok;
}

bool RouteMappingPiPhotoFetcher::triggerCapture(int sequence)
{
    if (!_enabled || !_acceptingCaptures) {
        return false;
    }
    if (_piHost.isEmpty() || _piUser.isEmpty() || sequence < 1) {
        return false;
    }

    const bool triggered =
        _sendRemoteUdpCommand(QStringLiteral("CAPTURE %1").arg(sequence), QStringLiteral("QUEUED"));
    if (triggered) {
        qCInfo(RouteMappingPiPhotoFetcherLog) << "Trigger queued sequence" << sequence;
    }
    return triggered;
}

void RouteMappingPiPhotoFetcher::fetchLatestPhoto(const QString &localFilePath, int requestId)
{
    fetchPhotoBySequence(0, localFilePath, requestId);
}

void RouteMappingPiPhotoFetcher::fetchPhotoBySequence(int sequence, const QString &localFilePath, int requestId)
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
    _queue.append(request);
    _startNextFetch();
#endif
}

void RouteMappingPiPhotoFetcher::_startNextFetch()
{
    if (_busy || _queue.isEmpty()) {
        return;
    }

    _busy = true;
    _listRemotePhotos(_queue.first());
}

void RouteMappingPiPhotoFetcher::_listRemotePhotos(FetchRequest request)
{
    QProcess *process = new QProcess(this);
    process->setProgram(QStringLiteral("ssh"));
    QStringList arguments = _baseSshOptions();

    QString remoteScript;
    if (request.bySequence) {
        const QString seqToken = QStringLiteral("image_%1_")
                                         .arg(request.photoSequence, 4, 10, QChar('0'));
        remoteScript = QStringLiteral(
                           "find '%1' -type f -name '%2*.jpg' ! -name '*.part.jpg' 2>/dev/null | sort | tail -1")
                           .arg(_piPhotoRoot, seqToken);
    } else {
        remoteScript = QStringLiteral(
                           "find '%1' -type f -name 'image_*.jpg' ! -name '*.part.jpg' 2>/dev/null | sort")
                           .arg(_piPhotoRoot);
    }
    arguments << _sshTarget() << remoteScript;
    process->setArguments(arguments);

    connect(process, &QProcess::finished, this, [this, request, process](int exitCode, QProcess::ExitStatus exitStatus) mutable {
        const QString stdoutText = trimmedProcessOutput(*process);
        const QString stderrText = trimmedProcessError(*process);
        process->deleteLater();

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

        if (!remotePath.startsWith(QLatin1Char('/')) || remotePath.contains(QLatin1Char('%'))) {
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
    });

    process->start();
}

void RouteMappingPiPhotoFetcher::_downloadRemotePhoto(FetchRequest request, const QString &remotePath)
{
    const QFileInfo localInfo(request.localFilePath);
    QDir().mkpath(localInfo.absolutePath());

    QProcess *process = new QProcess(this);
    process->setProgram(QStringLiteral("scp"));
    QStringList arguments = _baseSshOptions();
    arguments << QStringLiteral("%1:%2").arg(_sshTarget(), remotePath) << request.localFilePath;
    process->setArguments(arguments);

    connect(process, &QProcess::finished, this, [this, request, remotePath, process](int exitCode, QProcess::ExitStatus exitStatus) mutable {
        const QString stderrText = trimmedProcessError(*process);
        process->deleteLater();

        if (exitStatus != QProcess::NormalExit || exitCode != 0) {
            qCWarning(RouteMappingPiPhotoFetcherLog) << "SCP failed for" << remotePath << stderrText;
            _scheduleRetry(request);
            return;
        }

        const QFileInfo localInfo(request.localFilePath);
        if (!localInfo.isFile() || localInfo.size() == 0) {
            _scheduleRetry(request);
            return;
        }

        _downloadedRemotePaths.insert(remotePath);
        qCInfo(RouteMappingPiPhotoFetcherLog) << "Fetched" << remotePath << "to" << request.localFilePath;
        _finishFetch(request, true, {});
    });

    process->start();
}

void RouteMappingPiPhotoFetcher::_scheduleRetry(FetchRequest request)
{
    request.attempt++;
    if (request.attempt >= kMaxFetchAttempts) {
        _finishFetch(request, false, tr("Timed out waiting for Pi mapping photo"));
        return;
    }

    if (_queue.isEmpty()) {
        _busy = false;
        return;
    }

    _queue[0] = request;

    QTimer::singleShot(kRetryDelayMs, this, [this]() {
        if (_queue.isEmpty()) {
            _busy = false;
            return;
        }
        _listRemotePhotos(_queue.first());
    });
}

void RouteMappingPiPhotoFetcher::_finishFetch(const FetchRequest &request, bool success, const QString &errorMessage)
{
    emit photoFetched(request.requestId, request.localFilePath, success, errorMessage);

    if (!_queue.isEmpty()) {
        _queue.removeFirst();
    }
    _busy = false;
    _startNextFetch();
}
