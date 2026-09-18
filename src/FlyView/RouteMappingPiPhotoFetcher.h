#pragma once

#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtQmlIntegration/QtQmlIntegration>

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

    Q_INVOKABLE void resetSession();
    Q_INVOKABLE void cancelSession();
    Q_INVOKABLE bool testConnection() const;
    Q_INVOKABLE bool triggerCapture(int sequence);
    Q_INVOKABLE bool pauseLiveVideo();
    Q_INVOKABLE bool resumeLiveVideo();
    Q_INVOKABLE void fetchLatestPhoto(const QString &localFilePath, int requestId);
    Q_INVOKABLE void fetchPhotoBySequence(int sequence, const QString &localFilePath, int requestId);

signals:
    void piHostChanged();
    void piUserChanged();
    void piPhotoRootChanged();
    void piTriggerPortChanged();
    void enabledChanged();
    void photoFetched(int requestId, const QString &localFilePath, bool success, const QString &errorMessage);

private:
    struct FetchRequest {
        int requestId = 0;
        QString localFilePath;
        int attempt = 0;
        int photoSequence = 0;
        bool bySequence = false;
    };

    void _startNextFetch();
    void _listRemotePhotos(FetchRequest request);
    void _downloadRemotePhoto(FetchRequest request, const QString &remotePath);
    void _finishFetch(const FetchRequest &request, bool success, const QString &errorMessage);
    void _scheduleRetry(FetchRequest request);
    QString _sshTarget() const;
    static QStringList _baseSshOptions();
    bool _sendRemoteUdpCommand(const QString &command, const QString &successToken) const;

    QString _piHost = QStringLiteral("10.5.0.2");
    QString _piUser = QStringLiteral("shreeon");
    QString _piPhotoRoot = QStringLiteral("/home/shreeon/mapping_photos");
    int _piTriggerPort = 14551;
    bool _enabled = true;
    bool _acceptingCaptures = true;

    QSet<QString> _downloadedRemotePaths;
    QList<FetchRequest> _queue;
    bool _busy = false;
};
