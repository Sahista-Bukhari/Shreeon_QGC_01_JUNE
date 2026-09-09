#include "RouteMappingPiPhotoFetcher.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QProcess>
#include <QtCore/QTimer>

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

void RouteMappingPiPhotoFetcher::fetchLatestPhoto(const QString &localFilePath, int requestId)
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
    Q_UNUSED(requestId);
    emit photoFetched(requestId, localFilePath, false, tr("Pi SSH photo fetch is not supported on Windows"));
    return;
#else
    FetchRequest request;
    request.requestId = requestId;
    request.localFilePath = localFilePath;
    request.attempt = 0;
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
    const QString remoteScript = QStringLiteral(
        "find %1 -type f -name 'image_*.jpg' ! -name '*.part.jpg' -printf '%T@ %p\\n' 2>/dev/null | sort -n")
                                      .arg(_piPhotoRoot);
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

        const QStringList lines = stdoutText.split('\n', Qt::SkipEmptyParts);
        QString remotePath;
        for (int index = lines.size() - 1; index >= 0; --index) {
            const int spaceIndex = lines.at(index).indexOf(' ');
            if (spaceIndex <= 0) {
                continue;
            }
            const QString candidate = lines.at(index).mid(spaceIndex + 1).trimmed();
            if (candidate.isEmpty() || _downloadedRemotePaths.contains(candidate)) {
                continue;
            }
            remotePath = candidate;
            break;
        }

        if (remotePath.isEmpty()) {
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
        _finishFetch(request, false, tr("Timed out waiting for a new Pi mapping photo"));
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
