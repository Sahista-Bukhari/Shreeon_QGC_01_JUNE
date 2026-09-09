#pragma once

#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtQmlIntegration/QtQmlIntegration>

/// Fetches full-resolution mapping JPEGs from the Raspberry Pi over SSH/SCP.
/// Used by Route Mapping Fly View only; the Pi capture service is unchanged.
class RouteMappingPiPhotoFetcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString piHost READ piHost WRITE setPiHost NOTIFY piHostChanged)
    Q_PROPERTY(QString piUser READ piUser WRITE setPiUser NOTIFY piUserChanged)
    Q_PROPERTY(QString piPhotoRoot READ piPhotoRoot WRITE setPiPhotoRoot NOTIFY piPhotoRootChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit RouteMappingPiPhotoFetcher(QObject *parent = nullptr);

    QString piHost() const { return _piHost; }
    void setPiHost(const QString &host);

    QString piUser() const { return _piUser; }
    void setPiUser(const QString &user);

    QString piPhotoRoot() const { return _piPhotoRoot; }
    void setPiPhotoRoot(const QString &root);

    bool enabled() const { return _enabled; }
    void setEnabled(bool enabled);

    Q_INVOKABLE void resetSession();
    Q_INVOKABLE bool testConnection() const;
    Q_INVOKABLE void fetchLatestPhoto(const QString &localFilePath, int requestId);

signals:
    void piHostChanged();
    void piUserChanged();
    void piPhotoRootChanged();
    void enabledChanged();
    void photoFetched(int requestId, const QString &localFilePath, bool success, const QString &errorMessage);

private:
    struct FetchRequest {
        int requestId = 0;
        QString localFilePath;
        int attempt = 0;
    };

    void _startNextFetch();
    void _listRemotePhotos(FetchRequest request);
    void _downloadRemotePhoto(FetchRequest request, const QString &remotePath);
    void _finishFetch(const FetchRequest &request, bool success, const QString &errorMessage);
    void _scheduleRetry(FetchRequest request);
    QString _sshTarget() const;
    static QStringList _baseSshOptions();

    QString _piHost = QStringLiteral("10.5.0.2");
    QString _piUser = QStringLiteral("shreeon");
    QString _piPhotoRoot = QStringLiteral("/home/shreeon/mapping_photos");
    bool _enabled = true;

    QSet<QString> _downloadedRemotePaths;
    QList<FetchRequest> _queue;
    bool _busy = false;
};
