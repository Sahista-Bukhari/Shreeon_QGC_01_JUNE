#pragma once

#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtQmlIntegration/QtQmlIntegration>

class QRegularExpression;

/// Triggers Pi still capture over UDP and fetches JPEGs over SSH/SCP.
class RouteMappingPiPhotoFetcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString piHost READ piHost WRITE setPiHost NOTIFY piHostChanged)
    Q_PROPERTY(QString piUser READ piUser WRITE setPiUser NOTIFY piUserChanged)
    Q_PROPERTY(QString piPhotoRoot READ piPhotoRoot WRITE setPiPhotoRoot NOTIFY piPhotoRootChanged)
    Q_PROPERTY(int piTriggerPort READ piTriggerPort WRITE setPiTriggerPort NOTIFY piTriggerPortChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(int pendingFetchCount READ pendingFetchCount NOTIFY pendingFetchCountChanged)
    Q_PROPERTY(QString piSessionPath READ piSessionPath NOTIFY piSessionPathChanged)
    Q_PROPERTY(bool piSessionStarting READ piSessionStarting NOTIFY piSessionStartingChanged)

public:
    explicit RouteMappingPiPhotoFetcher(QObject *parent = nullptr);

    QString piHost() const { return _piHost; }
    void setPiHost(const QString &host);

    QString piUser() const { return _piUser; }
    void setPiUser(const QString &user);

    QString piPhotoRoot() const { return _piPhotoRoot; }
    void setPiPhotoRoot(const QString &root);

    int piTriggerPort() const { return _piTriggerPort; }
    void setPiTriggerPort(int port);

    bool enabled() const { return _enabled; }
    void setEnabled(bool enabled);

    int pendingFetchCount() const { return _queue.size(); }
    QString piSessionPath() const { return _piSessionPath; }
    bool piSessionStarting() const { return _piSessionStarting; }

    Q_INVOKABLE void beginSessionAsync();
    Q_INVOKABLE bool beginSession();
    Q_INVOKABLE void finishSession();
    Q_INVOKABLE void resetSession();
    Q_INVOKABLE void cancelSession();
    Q_INVOKABLE bool testConnection() const;
    Q_INVOKABLE void warmUpConnection();
    Q_INVOKABLE bool triggerCapture(int sequence, QString *remotePhotoPath = nullptr);
    Q_INVOKABLE void triggerCaptureQueued(int sequence);
    Q_INVOKABLE bool pauseLiveVideo();
    Q_INVOKABLE bool resumeLiveVideo();
    Q_INVOKABLE void fetchLatestPhoto(const QString &localFilePath, int requestId);
    Q_INVOKABLE void fetchPhotoBySequence(int sequence, const QString &localFilePath, int requestId, const QString &remotePhotoPath = {});

signals:
    void triggerCaptureFinished(int sequence, bool success, const QString &remotePhotoPath);
    void piHostChanged();
    void piUserChanged();
    void piPhotoRootChanged();
    void piTriggerPortChanged();
    void enabledChanged();
    void pendingFetchCountChanged();
    void piSessionPathChanged();
    void piSessionStartingChanged();
    void piSessionBeginComplete(bool success);
    void fetchQueueDrained();
    void sshPrecheckFailed(const QString &errorMessage);
    void sessionStartFailed(const QString &errorMessage);
    void photoFetched(int requestId, const QString &localFilePath, bool success, const QString &errorMessage);

private:
    struct FetchRequest {
        int requestId = 0;
        QString localFilePath;
        int attempt = 0;
        int photoSequence = 0;
        bool bySequence = false;
        bool transferStarted = false;
        quint64 generation = 0;
        QString remoteSessionPath;
        QString remotePhotoPath;
    };

    void _startNextFetch();
    void _beginFetchTransfer(FetchRequest request);
    int _indexOfFetchRequest(int requestId) const;
    void _listRemotePhotos(FetchRequest request);
    void _downloadRemotePhoto(FetchRequest request, const QString &remotePath);
    void _finishFetch(const FetchRequest &request, bool success, const QString &errorMessage);
    void _scheduleRetry(FetchRequest request, int retryDelayOverrideMs = -1);
    QString _sshTarget() const;
    static QStringList _baseSshOptions();
    bool _runSshPrecheck(QString *errorMessage) const;
    bool _requestRemoteUdpCommand(
        const QString &command,
        QString *response,
        QString *errorMessage,
        int timeoutMs = 8000,
        const QRegularExpression *acceptableReply = nullptr) const;
    bool _queryPiSessionPath(QString *sessionPath, QString *errorMessage) const;
    bool _sendVideoPauseAndWaitForSession(QString *sessionPath, QString *errorMessage) const;
    bool _sendRemoteUdpCommand(const QString &command) const;
    bool _parseCaptureUdpResponse(int sequence, const QString &response, QString *remotePhotoPath) const;
    bool _triggerCaptureViaSsh(int sequence, QString *remotePhotoPath, QString *errorMessage) const;

    QString _piHost = QStringLiteral("10.5.0.2");
    QString _piUser = QStringLiteral("shreeon");
    QString _piPhotoRoot = QStringLiteral("/home/shreeon/mapping_photos");
    int _piTriggerPort = 14551;
    bool _enabled = true;
    bool _acceptingCaptures = true;
    bool _piSessionStarting = false;
    QString _piSessionPath;
    quint64 _generation = 0;

    void _completeBeginSessionOnMainThread(
        quint64 generation, bool success, bool hadSshPrecheckFailure, const QString &sessionPath, const QString &errorMessage);

    QSet<QString> _downloadedRemotePaths;
    QList<FetchRequest> _queue;
    int _activeFetchCount = 0;
};
