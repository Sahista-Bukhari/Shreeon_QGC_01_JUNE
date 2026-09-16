#include "RouteMappingImageMetadata.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QRegularExpression>
#include <QtCore/QUuid>

QGC_LOGGING_CATEGORY(RouteMappingImageMetadataLog, "Utilities.RouteMappingImageMetadata")

namespace {
constexpr const char *kRouteMappingRoot =
    "/home/shreeon-technologies/Documents/QGC_RouteMapping/";
constexpr const char *kMetadataSubDir = "metadata/";
constexpr const char *kSessionFileName = "session.json";
constexpr const char *kManifestFileName = "manifest.jsonl";
constexpr const char *kMissionIdKey = "missionRouteMappingId";
} // namespace

QString RouteMappingImageMetadata::metadataDirectory()
{
    return QString::fromUtf8(kRouteMappingRoot) + QString::fromUtf8(kMetadataSubDir);
}

QString RouteMappingImageMetadata::missionSessionFilePath()
{
    return QString::fromUtf8(kRouteMappingRoot) + QString::fromUtf8(kSessionFileName);
}

QString RouteMappingImageMetadata::loadOrCreateMissionRouteMappingId()
{
    const QString sessionPath = missionSessionFilePath();
    QDir rootDir(QString::fromUtf8(kRouteMappingRoot));
    if (!rootDir.exists()) {
        rootDir.mkpath(QStringLiteral("."));
    }

    QFile sessionFile(sessionPath);
    if (sessionFile.exists() && sessionFile.open(QIODevice::ReadOnly)) {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(sessionFile.readAll(), &parseError);
        sessionFile.close();
        if (parseError.error == QJsonParseError::NoError && document.isObject()) {
            const QString existingId = document.object().value(QString::fromUtf8(kMissionIdKey)).toString();
            if (!existingId.isEmpty()) {
                return existingId;
            }
        }
    }

    const QString newId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QJsonObject sessionObject;
    sessionObject[QString::fromUtf8(kMissionIdKey)] = newId;
    sessionObject[QStringLiteral("createdUtc")] =
        QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    if (sessionFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        sessionFile.write(QJsonDocument(sessionObject).toJson(QJsonDocument::Compact));
        sessionFile.close();
    }

    return newId;
}

int RouteMappingImageMetadata::sequenceFromImageFileName(const QString &filePath)
{
    const QRegularExpression pattern(QStringLiteral("^image_(\\d+)\\.jpg$"),
                                     QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch match = pattern.match(QFileInfo(filePath).fileName());
    if (match.hasMatch()) {
        return match.captured(1).toInt();
    }
    return 0;
}

bool RouteMappingImageMetadata::writeSidecar(const RouteMappingImageTelemetry &telemetry, QString *errorOut)
{
    QDir metadataDir(metadataDirectory());
    if (!metadataDir.exists() && !metadataDir.mkpath(QStringLiteral("."))) {
        if (errorOut) {
            *errorOut = QStringLiteral("Failed to create metadata directory");
        }
        return false;
    }

    const QString baseName = QFileInfo(telemetry.filename).completeBaseName();
    const QString sidecarPath = metadataDir.filePath(baseName + QStringLiteral(".json"));

    QJsonObject object;
    object[QStringLiteral("filename")] = telemetry.filename;
    object[QStringLiteral("sequence")] = telemetry.sequence;
    object[QStringLiteral("missionRouteMappingId")] = telemetry.missionRouteMappingId;
    object[QStringLiteral("timestampUtc")] = telemetry.timestampUtc.toString(Qt::ISODate);
    object[QStringLiteral("vehicleId")] = telemetry.vehicleId;
    object[QStringLiteral("gpsValid")] = telemetry.gpsValid;
    if (telemetry.gpsValid) {
        object[QStringLiteral("latitude")] = telemetry.coordinate.latitude();
        object[QStringLiteral("longitude")] = telemetry.coordinate.longitude();
        object[QStringLiteral("altitude")] = telemetry.coordinate.altitude();
    }

    QFile sidecarFile(sidecarPath);
    if (!sidecarFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (errorOut) {
            *errorOut = QStringLiteral("Failed to write metadata: %1").arg(sidecarPath);
        }
        return false;
    }
    sidecarFile.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
    sidecarFile.close();

    qCInfo(RouteMappingImageMetadataLog) << "Wrote metadata" << sidecarPath;
    return appendManifestLine(telemetry, errorOut);
}

bool RouteMappingImageMetadata::appendManifestLine(const RouteMappingImageTelemetry &telemetry, QString *errorOut)
{
    QDir metadataDir(metadataDirectory());
    const QString manifestPath = metadataDir.filePath(QString::fromUtf8(kManifestFileName));

    QJsonObject object;
    object[QStringLiteral("filename")] = telemetry.filename;
    object[QStringLiteral("sequence")] = telemetry.sequence;
    object[QStringLiteral("missionRouteMappingId")] = telemetry.missionRouteMappingId;
    object[QStringLiteral("timestampUtc")] = telemetry.timestampUtc.toString(Qt::ISODate);
    object[QStringLiteral("vehicleId")] = telemetry.vehicleId;
    object[QStringLiteral("gpsValid")] = telemetry.gpsValid;
    if (telemetry.gpsValid) {
        object[QStringLiteral("latitude")] = telemetry.coordinate.latitude();
        object[QStringLiteral("longitude")] = telemetry.coordinate.longitude();
        object[QStringLiteral("altitude")] = telemetry.coordinate.altitude();
    }

    QFile manifestFile(manifestPath);
    if (!manifestFile.open(QIODevice::WriteOnly | QIODevice::Append)) {
        if (errorOut) {
            *errorOut = QStringLiteral("Failed to append manifest: %1").arg(manifestPath);
        }
        return false;
    }
    manifestFile.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    manifestFile.write("\n");
    manifestFile.close();
    return true;
}
