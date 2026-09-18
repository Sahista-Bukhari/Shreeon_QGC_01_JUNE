#include "RouteMappingPhotoController.h"

#include "RouteMappingPiPhotoFetcher.h"
#include "SettingsManager.h"
#include "AppSettings.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>

RouteMappingPhotoController::RouteMappingPhotoController(QObject *parent)
    : QObject(parent)
{
}

void RouteMappingPhotoController::setCaptureEnabled(bool enabled)
{
    if (_captureEnabled == enabled) {
        return;
    }
    _captureEnabled = enabled;
    emit captureEnabledChanged();
}

void RouteMappingPhotoController::setPhotoFetcher(QObject *fetcher)
{
    _fetcher = qobject_cast<RouteMappingPiPhotoFetcher *>(fetcher);
}

QString RouteMappingPhotoController::_routeMappingRoot() const
{
    const QString photoRoot = SettingsManager::instance()->appSettings()->photoSavePath();
    if (photoRoot.isEmpty()) {
        return {};
    }
    return QDir(photoRoot).filePath(QStringLiteral("RouteMapping"));
}

void RouteMappingPhotoController::beginSession()
{
    if (_sessionActive) {
        return;
    }

    const QString routeMappingRoot = _routeMappingRoot();
    if (routeMappingRoot.isEmpty()) {
        return;
    }

    const QString sessionName = QStringLiteral("Mission_%1").arg(
        QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss")));
    const QString sessionPath = QDir(routeMappingRoot).filePath(sessionName);
    if (!QDir().mkpath(sessionPath)) {
        return;
    }

    _sessionDirectory = sessionPath;
    _sessionActive = true;
    emit sessionDirectoryChanged();
    emit sessionActiveChanged();
}

void RouteMappingPhotoController::endSession()
{
    if (!_sessionActive) {
        return;
    }

    if (_fetcher) {
        _fetcher->cancelSession();
    }

    _sessionActive = false;
    emit sessionActiveChanged();
}

QString RouteMappingPhotoController::imagePathForSequence(int sequence) const
{
    if (!_sessionActive || sequence < 1) {
        return {};
    }
    return QDir(_sessionDirectory).filePath(
        QStringLiteral("image_%1.jpg").arg(sequence, 4, 10, QChar('0')));
}

QString RouteMappingPhotoController::metadataPathForSequence(int sequence) const
{
    if (!_sessionActive || sequence < 1) {
        return {};
    }
    return QDir(_sessionDirectory).filePath(
        QStringLiteral("image_%1.json").arg(sequence, 4, 10, QChar('0')));
}

bool RouteMappingPhotoController::_writeMetadata(int sequence, double latitude, double longitude, double altitude, double heading) const
{
    const QString metaPath = metadataPathForSequence(sequence);
    if (metaPath.isEmpty()) {
        return false;
    }

    QJsonObject object;
    object.insert(QStringLiteral("triggerIndex"), sequence);
    object.insert(QStringLiteral("timestamp"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    object.insert(QStringLiteral("latitude"), latitude);
    object.insert(QStringLiteral("longitude"), longitude);
    object.insert(QStringLiteral("altitude"), altitude);
    object.insert(QStringLiteral("heading"), heading);

    QFile file(metaPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return false;
    }
    file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    return true;
}

bool RouteMappingPhotoController::requestPhotoCapture(int sequence, double latitude, double longitude, double altitude, double heading)
{
    if (!_captureEnabled || !_sessionActive || sequence < 1 || !_fetcher) {
        return false;
    }

    const QString imagePath = imagePathForSequence(sequence);
    if (imagePath.isEmpty()) {
        return false;
    }

    QDir().mkpath(_sessionDirectory);
    (void)_writeMetadata(sequence, latitude, longitude, altitude, heading);

    if (!_fetcher->triggerCapture(sequence)) {
        return false;
    }

    _fetcher->fetchPhotoBySequence(sequence, imagePath, sequence);
    emit captureRequested(sequence, imagePath);
    return true;
}
