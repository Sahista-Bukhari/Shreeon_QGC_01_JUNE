#pragma once

#include <QtCore/QList>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtQmlIntegration/QtQmlIntegration>

class RouteMappingPiPhotoFetcher;

/// Route Mapping photo session on GCS: Documents/Photo/RouteMapping/Mission_* paths and metadata.
class RouteMappingPhotoController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool sessionActive READ sessionActive NOTIFY sessionActiveChanged)
    Q_PROPERTY(bool piSessionPending READ piSessionPending NOTIFY piSessionPendingChanged)
    Q_PROPERTY(QString sessionDirectory READ sessionDirectory NOTIFY sessionDirectoryChanged)
    Q_PROPERTY(QString routeMappingRoot READ routeMappingRoot NOTIFY routeMappingRootChanged)
    Q_PROPERTY(QString photoSaveRoot READ photoSaveRoot NOTIFY routeMappingRootChanged)
    Q_PROPERTY(bool captureEnabled READ captureEnabled WRITE setCaptureEnabled NOTIFY captureEnabledChanged)
    Q_PROPERTY(int pendingCaptureCount READ pendingCaptureCount NOTIFY pendingCaptureCountChanged)

   public:
    explicit RouteMappingPhotoController(QObject *parent = nullptr);

    bool sessionActive() const { return _sessionActive; }
    bool piSessionPending() const { return _waitingForPiSession; }
    QString sessionDirectory() const { return _sessionDirectory; }
    QString routeMappingRoot() const { return _routeMappingRoot(false); }
    QString photoSaveRoot() const;

    bool captureEnabled() const { return _captureEnabled; }
    void setCaptureEnabled(bool enabled);

    int pendingCaptureCount() const
    {
        return _pendingCaptures.size() + (_captureUdpInFlight ? 1 : 0);
    }

    Q_INVOKABLE void setPhotoFetcher(QObject *fetcher);
    Q_INVOKABLE bool beginSession();
    Q_INVOKABLE void endSession();
    Q_INVOKABLE void cancelSession();
    Q_INVOKABLE void discardSessionStorage();
    Q_INVOKABLE QString imagePathForSequence(int sequence) const;
    Q_INVOKABLE QString metadataPathForSequence(int sequence) const;
    Q_INVOKABLE bool requestPhotoCapture(int sequence, quint32 nativeTriggerSequence, double latitude, double longitude, double altitude, double heading);

   signals:
    void sessionActiveChanged();
    void piSessionPendingChanged();
    void sessionDirectoryChanged();
    void routeMappingRootChanged();
    void captureEnabledChanged();
    void pendingCaptureCountChanged();
    void captureRequested(int sequence, const QString &localImagePath);
    void captureFailed(int sequence, const QString &errorMessage);
    void gcsSessionStartFailed(const QString &errorMessage);

   private slots:
    void _onPiSessionBeginComplete(bool success);
    void _pumpCaptureQueue();
    void _onTriggerCaptureFinished(
        int sequence, bool success, const QString &remotePhotoPath, const QString &remoteThumbnailPath);

   private:
    struct PendingCapture {
        int sequence = 0;
        quint32 nativeTriggerSequence = 0;
        double latitude = 0;
        double longitude = 0;
        double altitude = 0;
        double heading = 0;
        int udpAttempts = 0;
    };

    bool _writeMetadata(int sequence, quint32 nativeTriggerSequence, double latitude, double longitude, double altitude, double heading) const;
    QString _routeMappingRoot(bool ensureExists) const;
    void _writeSessionLocatorFiles(const QString &sessionPath) const;
    void _ensureRouteMappingReadme(const QString &routeMappingRoot, const QString &photoRoot) const;
    void _removeEmptySessionDirectory(const QString &sessionPath) const;
    void _scheduleCapturePump();
    void _notifyPendingCaptureCountChanged();
    void _finishSessionIfReady();
    void _completeCaptureAttempt(
        int sequence,
        double latitude,
        double longitude,
        double altitude,
        double heading,
        bool success,
        const QString &remotePhotoPath,
        const QString &remoteThumbnailPath);
    RouteMappingPiPhotoFetcher *_fetcher = nullptr;
    QList<PendingCapture> _pendingCaptures;
    QSet<int> _requestedCaptureSequences;
    bool _capturePumpRunning = false;
    bool _captureUdpInFlight = false;
    PendingCapture _inFlightCapture;
    bool _inFlightCaptureValid = false;
    QString _sessionDirectory;
    QString _sessionToken;
    bool _sessionActive = false;
    bool _waitingForPiSession = false;
    bool _captureEnabled = true;
    bool _finishRequested = false;
};
