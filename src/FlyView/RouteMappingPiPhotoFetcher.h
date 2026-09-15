#pragma once

#include <QtCore/QList>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QProcess>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtQmlIntegration/QtQmlIntegration>

#include <functional>

/// Asynchronously captures a real still image on the Raspberry Pi, downloads
/// it over SCP, validates and commits it locally, then deletes the Pi copy.
class RouteMappingPiPhotoFetcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString piHost READ piHost WRITE setPiHost NOTIFY piHostChanged)
    Q_PROPERTY(QString piUser READ piUser WRITE setPiUser NOTIFY piUserChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

   public:
    explicit RouteMappingPiPhotoFetcher(QObject* parent = nullptr);

    QString piHost() const
    {
        return _piHost;
    }
    void setPiHost(const QString& host);

    QString piUser() const
    {
        return _piUser;
    }
    void setPiUser(const QString& user);

    bool enabled() const
    {
        return _enabled;
    }
    void setEnabled(bool enabled);

    bool busy() const
    {
        return _busy;
    }

    Q_INVOKABLE void resetSession();
    Q_INVOKABLE void capturePhoto(const QString& localFilePath, int requestId);

   signals:
    void piHostChanged();
    void piUserChanged();
    void enabledChanged();
    void busyChanged();
    void photoFetched(int requestId, const QString& localFilePath, bool success, const QString& errorMessage);

   private:
    struct CaptureRequest
    {
        int requestId = 0;
        int attempt = 0;
        int acknowledgeAttempt = 0;
        quint64 generation = 0;
        QString token;
        QString remotePath;
        QString localFilePath;
        QString localPartPath;
    };

    using ProcessCallback = std::function<void(bool, const QByteArray&, const QString&)>;

    void _startNextRequest();
    void _startRemoteCapture(CaptureRequest request);
    void _startDownload(CaptureRequest request);
    void _startRemoteAcknowledge(CaptureRequest request);
    void _retry(CaptureRequest request, const QString& errorMessage);
    void _finish(const CaptureRequest& request, bool success, const QString& errorMessage);

    void _runProcess(const QString& program, const QStringList& arguments, int timeoutMs, ProcessCallback callback);

    QString _sshTarget() const;
    QStringList _sshOptions() const;
    bool _configurationValid() const;

    QString _piHost = QStringLiteral("10.5.0.2");
    QString _piUser = QStringLiteral("shreeon");
    QString _sessionToken;
    bool _enabled = true;
    bool _busy = false;
    quint64 _generation = 0;

    QList<CaptureRequest> _queue;
    QSet<int> _pendingRequestIds;
    QSet<int> _completedRequestIds;
    QPointer<QProcess> _activeProcess;
};
