#pragma once

#include <QtCore/QHash>
#include <QtCore/QList>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QStringList>
#include <QtCore/QTimer>
#include <QtPositioning/QGeoCoordinate>
#include <QtQmlIntegration/QtQmlIntegration>

class RouteMappingPiPhotoFetcher;
class QFile;
class QNetworkAccessManager;
class QNetworkReply;

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
    Q_PROPERTY(int geotaggedPhotoCount READ geotaggedPhotoCount NOTIFY reconstructionStateChanged)
    Q_PROPERTY(bool odmReady READ odmReady NOTIFY reconstructionStateChanged)
    Q_PROPERTY(bool odmRunning READ odmRunning NOTIFY reconstructionStateChanged)
    Q_PROPERTY(bool odmComplete READ odmComplete NOTIFY reconstructionStateChanged)
    Q_PROPERTY(int reconstructionProgress READ reconstructionProgress NOTIFY reconstructionStateChanged)
    Q_PROPERTY(QString reconstructionStatus READ reconstructionStatus NOTIFY reconstructionStateChanged)
    Q_PROPERTY(QString orthophotoPath READ orthophotoPath NOTIFY reconstructionStateChanged)
    Q_PROPERTY(QString orthophotoUrl READ orthophotoUrl NOTIFY orthophotoOverlayChanged)
    Q_PROPERTY(QGeoCoordinate orthophotoNorthWest READ orthophotoNorthWest NOTIFY orthophotoOverlayChanged)
    Q_PROPERTY(QGeoCoordinate orthophotoSouthEast READ orthophotoSouthEast NOTIFY orthophotoOverlayChanged)
    Q_PROPERTY(bool orthophotoOverlayReady READ orthophotoOverlayReady NOTIFY orthophotoOverlayChanged)

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
    int geotaggedPhotoCount() const { return _geotaggedSequences.size(); }
    bool odmReady() const;
    bool odmRunning() const;
    bool odmComplete() const { return _odmComplete; }
    int reconstructionProgress() const { return _odmProgress; }
    QString reconstructionStatus() const;
    QString orthophotoPath() const { return _orthophotoPath; }
    QString orthophotoUrl() const { return _orthophotoUrl; }
    QGeoCoordinate orthophotoNorthWest() const { return _orthophotoNorthWest; }
    QGeoCoordinate orthophotoSouthEast() const { return _orthophotoSouthEast; }
    bool orthophotoOverlayReady() const
    {
        return !_orthophotoUrl.isEmpty()
        && _orthophotoNorthWest.isValid()
            && _orthophotoSouthEast.isValid();
    }

    Q_INVOKABLE void setPhotoFetcher(QObject *fetcher);
    Q_INVOKABLE bool beginSession();
    /// Stop accepting new triggers but send every capture already positioned by the survey schedule.
    Q_INVOKABLE void finishCaptureQueue();
    Q_INVOKABLE void endSession();
    Q_INVOKABLE void cancelSession();
    Q_INVOKABLE void discardSessionStorage();
    Q_INVOKABLE QString imagePathForSequence(int sequence) const;
    Q_INVOKABLE QString metadataPathForSequence(int sequence) const;
    Q_INVOKABLE bool requestPhotoCapture(int sequence, quint32 nativeTriggerSequence, double latitude, double longitude, double relativeAltitude, double heading);
    Q_INVOKABLE bool startOdm();

   signals:
    void sessionActiveChanged();
    void piSessionPendingChanged();
    void sessionDirectoryChanged();
    void routeMappingRootChanged();
    void captureEnabledChanged();
    void pendingCaptureCountChanged();
    void reconstructionStateChanged();
    void orthophotoOverlayChanged();
    void captureRequested(int sequence, const QString &localImagePath);
    void captureFailed(int sequence, const QString &errorMessage);
    void gcsSessionStartFailed(const QString &errorMessage);
    void odmError(const QString &errorMessage);

   private slots:
    void _onPiSessionBeginComplete(bool success);
    void _pumpCaptureQueue();
    void _onTriggerCaptureFinished(
        int sequence, bool success, const QString &remotePhotoPath, const QString &remoteThumbnailPath);
    void _onPhotoFetched(int requestId, const QString &localFilePath, bool success, const QString &errorMessage);
    void _onFetcherPendingCountChanged();

   private:
    struct PendingCapture {
        int sequence = 0;
        quint32 nativeTriggerSequence = 0;
        double latitude = 0;
        double longitude = 0;
        double relativeAltitude = 0;
        double heading = 0;
        qint64 captureTimeMsecsUtc = 0;
        int udpAttempts = 0;
    };

    bool _writeMetadata(int sequence, quint32 nativeTriggerSequence, double latitude, double longitude, double relativeAltitude, double heading, qint64 captureTimeMsecsUtc) const;
    bool _appendOdmGeotag(int sequence, const QString &localFilePath);
    enum class OdmState {
        Idle,
        Connecting,
        Uploading,
        Queued,
        Processing,
        Downloading,
        Complete,
        Failed,
    };

    void _beginNodeOdmUpload();
    void _pollNodeOdmTask();
    void _downloadNodeOdmOrthophoto();
    void _finishNodeOdmDownload(QNetworkReply *reply);
    void _prepareOrthophotoOverlay();
    void _reportOrthophotoOverlayError(const QString &errorMessage);
    void _setOdmState(OdmState state, int progress, const QString &detail = {});
    void _failOdm(const QString &errorMessage);
    void _writeOdmStateFile() const;
    QString _nodeOdmStatusText() const;
    QString _routeMappingRoot(bool ensureExists) const;
    void _writeSessionLocatorFiles(const QString &sessionPath) const;
    void _ensureRouteMappingReadme(const QString &routeMappingRoot, const QString &photoRoot) const;
    void _removeFailedSessionDirectory(const QString &sessionPath) const;
    void _scheduleCapturePump();
    void _notifyPendingCaptureCountChanged();
    void _finishSessionIfReady();
    void _completeCaptureAttempt(
        int sequence,
        double latitude,
        double longitude,
        double relativeAltitude,
        double heading,
        bool success,
        const QString &remotePhotoPath,
        const QString &remoteThumbnailPath);
    RouteMappingPiPhotoFetcher *_fetcher = nullptr;
    QList<PendingCapture> _pendingCaptures;
    QSet<int> _requestedCaptureSequences;
    QHash<int, PendingCapture> _captureMetadata;
    QSet<int> _geotaggedSequences;
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
    QNetworkAccessManager *_nodeOdmNetworkManager = nullptr;
    QNetworkReply *_odmPollReply = nullptr;
    QFile *_odmDownloadFile = nullptr;
    QTimer _odmPollTimer;
    OdmState _odmState = OdmState::Idle;
    int _odmProgress = 0;
    int _odmPollFailures = 0;
    QStringList _odmInputFiles;
    QString _odmTaskUuid;
    QString _odmStateDetail;
    QString _odmDownloadPath;
    QString _odmSessionDirectory;
    QString _odmErrorMessage;
    QString _orthophotoPath;
    QString _orthophotoUrl;
    QGeoCoordinate _orthophotoNorthWest;
    QGeoCoordinate _orthophotoSouthEast;
    bool _odmComplete = false;
};
