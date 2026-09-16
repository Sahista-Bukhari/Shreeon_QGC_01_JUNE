#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QProcess>
#include <QtCore/QSet>
#include <QtCore/QStringList>

#include "RouteMappingImageMetadata.h"

Q_DECLARE_LOGGING_CATEGORY(RouteMappingPiPhotoCaptureLog)

class RouteMappingPiPhotoCapture : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString lastLocalPath READ lastLocalPath NOTIFY lastLocalPathChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int batchProgressTotal READ batchProgressTotal NOTIFY batchProgressChanged)
    Q_PROPERTY(int batchProgressCompleted READ batchProgressCompleted NOTIFY batchProgressChanged)

public:
    explicit RouteMappingPiPhotoCapture(QObject *parent = nullptr);
    ~RouteMappingPiPhotoCapture() override;

    static RouteMappingPiPhotoCapture *instance();

    bool busy() const { return _busy; }
    QString lastLocalPath() const { return _lastLocalPath; }
    QString lastError() const { return _lastError; }
    int batchProgressTotal() const { return _batchProgressTotal; }
    int batchProgressCompleted() const { return _batchProgressCompleted; }

    Q_INVOKABLE void captureOnePhoto();
    Q_INVOKABLE void captureMultiplePhotos(int count);
    Q_INVOKABLE static QString localSaveDirectory();
    Q_INVOKABLE static QString localMetadataDirectory();
    Q_INVOKABLE bool ensureLocalSaveDirectory();

signals:
    void busyChanged();
    void lastLocalPathChanged();
    void lastErrorChanged();
    void batchProgressChanged();
    void captureSucceeded(const QString &localPath);
    void captureFailed(const QString &errorMessage);
    void batchCaptureCompleted(int succeededCount, int requestedCount, const QStringList &localPaths);

private slots:
    void _onSshCaptureFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void _onScpFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void _onSshRemoveFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    enum class Step {
        Idle,
        RemoteCapture,
        ScpTransfer,
        RemoteCleanup,
    };

    void _setBusy(bool busy);
    void _setError(const QString &error);
    void _setBatchProgress(int completed, int total);
    void _beginSession(int photoCount);
    void _startNextPhotoInSession();
    void _retryCurrentStep(const QString &reason);
    void _abortSession(const QString &error);
    void _onPhotoPipelineSucceeded();
    void _onPhotoPipelineFailed(const QString &error);
    void _completeSession();
    void _snapshotPendingTelemetry();
    void _writeMetadataForCurrentPhoto();
    bool _ensureLocalDirectory(QString *errorOut);
    QString _allocateLocalFileName() const;
    QString _allocateRemotePath() const;
    QString _sshTarget() const;
    QStringList _baseSshOptions() const;
    void _startRemoteCapture();
    void _startScp();
    void _startRemoteCleanup();
    void _cleanupProcess();

    bool _busy = false;
    Step _step = Step::Idle;
    QString _lastLocalPath;
    QString _lastError;
    QString _remotePath;
    QProcess *_process = nullptr;

    int _sessionPhotoCount = 0;
    int _sessionPhotosRemaining = 0;
    int _batchProgressTotal = 0;
    int _batchProgressCompleted = 0;
    int _attemptNumber = 0;
    bool _cleanupAfterSuccess = false;
    QStringList _sessionSuccessfulPaths;
    QSet<QString> _transferredLocalPaths;
    QSet<QString> _transferredRemotePaths;
    RouteMappingImageTelemetry _pendingTelemetry;

    static constexpr int kMaxAttemptsPerPhoto = 3;
    static constexpr int kMaxBatchSize = 32;
    static constexpr int kRetryDelayMs = 1500;

    static constexpr const char *kSshUser = "shreeon";
    static constexpr const char *kSshHost = "10.5.0.2";
    static constexpr const char *kLocalSaveDir =
        "/home/shreeon-technologies/Documents/QGC_RouteMapping/images/";
    static constexpr const char *kRemoteCameraCommand = "/usr/local/bin/rpicam-still";
    static constexpr const char *kRemoteVideoService = "wfb-camera.service";
};
