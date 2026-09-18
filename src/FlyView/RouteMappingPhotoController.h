#pragma once

#include <QtCore/QObject>
#include <QtQmlIntegration/QtQmlIntegration>

class RouteMappingPiPhotoFetcher;

/// Route Mapping photo session on GCS: Documents/Photo/RouteMapping/Mission_* paths and metadata.
class RouteMappingPhotoController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool sessionActive READ sessionActive NOTIFY sessionActiveChanged)
    Q_PROPERTY(QString sessionDirectory READ sessionDirectory NOTIFY sessionDirectoryChanged)
    Q_PROPERTY(bool captureEnabled READ captureEnabled WRITE setCaptureEnabled NOTIFY captureEnabledChanged)

public:
    explicit RouteMappingPhotoController(QObject *parent = nullptr);

    bool sessionActive() const { return _sessionActive; }
    QString sessionDirectory() const { return _sessionDirectory; }

    bool captureEnabled() const { return _captureEnabled; }
    void setCaptureEnabled(bool enabled);

    Q_INVOKABLE void setPhotoFetcher(QObject *fetcher);
    Q_INVOKABLE void beginSession();
    Q_INVOKABLE void endSession();
    Q_INVOKABLE QString imagePathForSequence(int sequence) const;
    Q_INVOKABLE QString metadataPathForSequence(int sequence) const;
    Q_INVOKABLE bool requestPhotoCapture(int sequence, double latitude, double longitude, double altitude, double heading);

signals:
    void sessionActiveChanged();
    void sessionDirectoryChanged();
    void captureEnabledChanged();
    void captureRequested(int sequence, const QString &localImagePath);

private:
    bool _writeMetadata(int sequence, double latitude, double longitude, double altitude, double heading) const;
    QString _routeMappingRoot() const;

    RouteMappingPiPhotoFetcher *_fetcher = nullptr;
    QString _sessionDirectory;
    bool _sessionActive = false;
    bool _captureEnabled = true;
};
