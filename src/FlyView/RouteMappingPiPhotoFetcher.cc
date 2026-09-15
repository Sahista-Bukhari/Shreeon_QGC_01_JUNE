#include "RouteMappingPiPhotoFetcher.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QRegularExpression>
#include <QtCore/QTimer>
#include <QtCore/QUuid>
#include <QtGui/QImageReader>

#include <utility>

#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(RouteMappingPiPhotoFetcherLog, "FlyView.RouteMappingPiPhotoFetcher")

namespace {
constexpr int kCaptureTimeoutMs = 45000;
constexpr int kTransferTimeoutMs = 30000;
constexpr int kAcknowledgeTimeoutMs = 10000;
constexpr int kMaximumAttempts = 3;
constexpr int kRetryDelayMs = 1000;
constexpr int kMaximumQueuedRequests = 128;

const QString kRemoteHelper = QStringLiteral("/usr/local/libexec/shreeon-route-mapping-camera");
const QString kRemotePhotoDirectory = QStringLiteral("/run/shreeon-route-mapping/photos");
}  // namespace

RouteMappingPiPhotoFetcher::RouteMappingPiPhotoFetcher(QObject* parent) : QObject(parent)
{
    resetSession();
}

void RouteMappingPiPhotoFetcher::setPiHost(const QString& host)
{
    const QString value = host.trimmed();
    if (_piHost == value) {
        return;
    }

    _piHost = value;
    emit piHostChanged();
}

void RouteMappingPiPhotoFetcher::setPiUser(const QString& user)
{
    const QString value = user.trimmed();
    if (_piUser == value) {
        return;
    }

    _piUser = value;
    emit piUserChanged();
}

void RouteMappingPiPhotoFetcher::setEnabled(bool enabled)
{
    if (_enabled == enabled) {
        return;
    }

    _enabled = enabled;
    emit enabledChanged();
}

QString RouteMappingPiPhotoFetcher::_sshTarget() const
{
    return QStringLiteral("%1@%2").arg(_piUser, _piHost);
}

QStringList RouteMappingPiPhotoFetcher::_sshOptions() const
{
    return {
        QStringLiteral("-o"), QStringLiteral("BatchMode=yes"),
        QStringLiteral("-o"), QStringLiteral("ConnectTimeout=5"),
        QStringLiteral("-o"), QStringLiteral("ServerAliveInterval=3"),
        QStringLiteral("-o"), QStringLiteral("ServerAliveCountMax=2"),
        QStringLiteral("-o"), QStringLiteral("StrictHostKeyChecking=yes"),
    };
}

bool RouteMappingPiPhotoFetcher::_configurationValid() const
{
    static const QRegularExpression userExpression(QStringLiteral("^[A-Za-z_][A-Za-z0-9_-]*$"));
    static const QRegularExpression hostExpression(QStringLiteral("^[A-Za-z0-9.:-]+$"));

    return !_piUser.isEmpty() && !_piHost.isEmpty() && userExpression.match(_piUser).hasMatch() &&
           hostExpression.match(_piHost).hasMatch();
}

void RouteMappingPiPhotoFetcher::resetSession()
{
    ++_generation;

    if (_activeProcess) {
        _activeProcess->setProperty("routeMappingCompleted", true);
        const QList<QTimer*> timers = _activeProcess->findChildren<QTimer*>();
        for (QTimer* timer : timers) {
            timer->stop();
        }
        _activeProcess->kill();
        _activeProcess->deleteLater();
        _activeProcess = nullptr;
    }

    for (const CaptureRequest& request : std::as_const(_queue)) {
        if (!request.localPartPath.isEmpty()) {
            QFile::remove(request.localPartPath);
        }
    }

    _queue.clear();
    _pendingRequestIds.clear();
    _completedRequestIds.clear();
    _sessionToken = QUuid::createUuid().toString(QUuid::Id128);

    if (_busy) {
        _busy = false;
        emit busyChanged();
    }
}

void RouteMappingPiPhotoFetcher::capturePhoto(const QString& localFilePath, int requestId)
{
    if (!_enabled) {
        emit photoFetched(requestId, localFilePath, false, tr("Pi camera capture is disabled"));
        return;
    }
    if (!_configurationValid()) {
        emit photoFetched(requestId, localFilePath, false, tr("Invalid Raspberry Pi SSH configuration"));
        return;
    }
    if (localFilePath.trimmed().isEmpty()) {
        emit photoFetched(requestId, localFilePath, false, tr("Local photo path is empty"));
        return;
    }
    if (_pendingRequestIds.contains(requestId) || _completedRequestIds.contains(requestId)) {
        return;
    }
    if (_queue.size() >= kMaximumQueuedRequests) {
        emit photoFetched(requestId, localFilePath, false, tr("Pi camera capture queue is full"));
        return;
    }

    CaptureRequest request;
    request.requestId = requestId;
    request.generation = _generation;
    request.localFilePath = QDir::cleanPath(localFilePath);
    request.localPartPath = request.localFilePath + QStringLiteral(".part");
    request.token = QStringLiteral("qgc_%1_%2").arg(_sessionToken).arg(requestId);

    _pendingRequestIds.insert(requestId);
    _queue.append(request);
    _startNextRequest();
}

void RouteMappingPiPhotoFetcher::_startNextRequest()
{
    if (_busy || _queue.isEmpty()) {
        return;
    }

    _busy = true;
    emit busyChanged();
    _startRemoteCapture(_queue.first());
}

void RouteMappingPiPhotoFetcher::_startRemoteCapture(CaptureRequest request)
{
    QStringList arguments = _sshOptions();
    arguments << _sshTarget() << QStringLiteral("sudo") << QStringLiteral("-n") << kRemoteHelper
              << QStringLiteral("capture") << request.token;

    _runProcess(QStringLiteral("ssh"), arguments, kCaptureTimeoutMs,
                [this, request](bool success, const QByteArray& standardOutput, const QString& errorMessage) mutable {
                    if (request.generation != _generation) {
                        return;
                    }
                    if (!success) {
                        _retry(request, errorMessage);
                        return;
                    }

                    request.remotePath = QString::fromUtf8(standardOutput).trimmed();
                    const QString expectedPath = QStringLiteral("%1/%2.jpg").arg(kRemotePhotoDirectory, request.token);
                    if (request.remotePath != expectedPath) {
                        _retry(request, tr("Pi returned an unexpected photo path"));
                        return;
                    }

                    if (!_queue.isEmpty() && _queue.first().token == request.token) {
                        _queue[0] = request;
                    }
                    _startDownload(request);
                });
}

void RouteMappingPiPhotoFetcher::_startDownload(CaptureRequest request)
{
    const QFileInfo localInformation(request.localFilePath);
    if (!QDir().mkpath(localInformation.absolutePath())) {
        _finish(request, false, tr("Could not create the local Route Mapping photo directory"));
        return;
    }

    QFile::remove(request.localPartPath);
    QStringList arguments = _sshOptions();
    arguments << QStringLiteral("%1:%2").arg(_sshTarget(), request.remotePath) << request.localPartPath;

    _runProcess(QStringLiteral("scp"), arguments, kTransferTimeoutMs,
                [this, request](bool success, const QByteArray&, const QString& errorMessage) mutable {
                    if (request.generation != _generation) {
                        return;
                    }
                    if (!success) {
                        QFile::remove(request.localPartPath);
                        _retry(request, errorMessage);
                        return;
                    }

                    const QFileInfo downloadedFile(request.localPartPath);
                    if (!downloadedFile.isFile() || downloadedFile.size() < 4) {
                        QFile::remove(request.localPartPath);
                        _retry(request, tr("The downloaded Pi image is empty"));
                        return;
                    }

                    QImageReader reader(request.localPartPath);
                    reader.setDecideFormatFromContent(true);
                    if (!reader.canRead()) {
                        QFile::remove(request.localPartPath);
                        _retry(request, tr("The downloaded Pi file is not a readable image"));
                        return;
                    }

                    if (QFileInfo::exists(request.localFilePath)) {
                        QFile::remove(request.localPartPath);
                        _finish(request, false, tr("The destination Route Mapping image already exists"));
                        return;
                    }
                    if (!QFile::rename(request.localPartPath, request.localFilePath)) {
                        QFile::remove(request.localPartPath);
                        _retry(request, tr("Could not commit the downloaded image locally"));
                        return;
                    }

                    _startRemoteAcknowledge(request);
                });
}

void RouteMappingPiPhotoFetcher::_startRemoteAcknowledge(CaptureRequest request)
{
    QStringList arguments = _sshOptions();
    arguments << _sshTarget() << QStringLiteral("sudo") << QStringLiteral("-n") << kRemoteHelper
              << QStringLiteral("ack") << request.token;

    _runProcess(QStringLiteral("ssh"), arguments, kAcknowledgeTimeoutMs,
                [this, request](bool success, const QByteArray&, const QString& errorMessage) mutable {
                    if (request.generation != _generation) {
                        return;
                    }
                    if (!success) {
                        ++request.acknowledgeAttempt;
                        if (request.acknowledgeAttempt < kMaximumAttempts) {
                            const int delay = kRetryDelayMs * request.acknowledgeAttempt;
                            QTimer::singleShot(delay, this, [this, request]() {
                                if (request.generation == _generation) {
                                    _startRemoteAcknowledge(request);
                                }
                            });
                            return;
                        }
                        // The local file is already valid. The remote file is volatile and
                        // is also expired by the helper or removed when the Pi reboots.
                        qCWarning(RouteMappingPiPhotoFetcherLog) << "Pi photo cleanup failed:" << errorMessage;
                    }
                    _finish(request, true, {});
                });
}

void RouteMappingPiPhotoFetcher::_retry(CaptureRequest request, const QString& errorMessage)
{
    QFile::remove(request.localPartPath);
    ++request.attempt;
    if (request.attempt >= kMaximumAttempts) {
        _finish(request, false, errorMessage);
        return;
    }

    if (!_queue.isEmpty() && _queue.first().token == request.token) {
        _queue[0] = request;
    }

    const int delay = kRetryDelayMs * request.attempt;
    QTimer::singleShot(delay, this, [this, request]() {
        if (request.generation != _generation || _queue.isEmpty() || _queue.first().token != request.token) {
            return;
        }
        _startRemoteCapture(request);
    });
}

void RouteMappingPiPhotoFetcher::_finish(const CaptureRequest& request, bool success, const QString& errorMessage)
{
    if (request.generation != _generation) {
        return;
    }

    QFile::remove(request.localPartPath);
    _pendingRequestIds.remove(request.requestId);
    if (success) {
        _completedRequestIds.insert(request.requestId);
    }

    for (qsizetype index = 0; index < _queue.size(); ++index) {
        if (_queue.at(index).token == request.token) {
            _queue.removeAt(index);
            break;
        }
    }

    _busy = false;
    emit busyChanged();
    emit photoFetched(request.requestId, request.localFilePath, success, errorMessage);
    _startNextRequest();
}

void RouteMappingPiPhotoFetcher::_runProcess(const QString& program, const QStringList& arguments, int timeoutMs,
                                             ProcessCallback callback)
{
    QProcess* process = new QProcess(this);
    QTimer* timer = new QTimer(process);
    timer->setSingleShot(true);
    process->setProgram(program);
    process->setArguments(arguments);
    process->setProcessChannelMode(QProcess::SeparateChannels);
    _activeProcess = process;

    const auto complete = [this, process, timer, callback](bool success, const QString& forcedError) {
        if (process->property("routeMappingCompleted").toBool()) {
            return;
        }

        process->setProperty("routeMappingCompleted", true);
        timer->stop();
        const QByteArray standardOutput = process->readAllStandardOutput();
        const QString standardError = QString::fromUtf8(process->readAllStandardError()).trimmed();
        QString errorMessage = forcedError;
        if (!success && errorMessage.isEmpty()) {
            errorMessage = standardError.isEmpty() ? process->errorString() : standardError;
        }

        if (_activeProcess == process) {
            _activeProcess = nullptr;
        }
        process->deleteLater();
        callback(success, standardOutput, errorMessage);
    };

    connect(timer, &QTimer::timeout, this, [process, program, complete]() {
        process->kill();
        complete(false, tr("%1 timed out").arg(program));
    });
    connect(process, &QProcess::errorOccurred, this, [process, complete](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            complete(false, process->errorString());
        }
    });
    connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [complete](int exitCode, QProcess::ExitStatus exitStatus) {
                complete(exitStatus == QProcess::NormalExit && exitCode == 0, {});
            });

    process->start();
    timer->start(timeoutMs);
}
