#pragma once

#include <QtCore/QDateTime>
#include <QtPositioning/QGeoCoordinate>
#include <QtCore/QString>

struct RouteMappingImageTelemetry {
    QString filename;
    int sequence = 0;
    QString missionRouteMappingId;
    QDateTime timestampUtc;
    QGeoCoordinate coordinate;
    bool gpsValid = false;
    int vehicleId = -1;
};

class RouteMappingImageMetadata
{
public:
    static QString metadataDirectory();
    static QString missionSessionFilePath();
    static QString loadOrCreateMissionRouteMappingId();
    static int sequenceFromImageFileName(const QString &filePath);
    static bool writeSidecar(const RouteMappingImageTelemetry &telemetry, QString *errorOut = nullptr);
    static bool appendManifestLine(const RouteMappingImageTelemetry &telemetry, QString *errorOut = nullptr);
};
