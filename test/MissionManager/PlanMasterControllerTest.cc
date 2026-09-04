#include "PlanMasterControllerTest.h"
#include "MultiSignalSpyV2.h"
#include "MissionManager.h"
#include "PlanMasterController.h"
#include "QGCFileDialogController.h"
#include "Vehicle.h"

#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QTemporaryDir>
#include <QtTest/QTest>

PlanMasterControllerTest::PlanMasterControllerTest(void)
    : _masterController(nullptr)
{

}

void PlanMasterControllerTest::init(void)
{
    UnitTest::init();

    _masterController = new PlanMasterController(this);
    _masterController->setFlyView(false);
    _masterController->start();
}

void PlanMasterControllerTest::cleanup(void)
{
    delete _masterController;
    _masterController = nullptr;
    UnitTest::cleanup();
}

void PlanMasterControllerTest::_testMissionPlannerFileLoad(void)
{
    _masterController->loadFromFile(":/unittest/MissionPlanner.waypoints");
    QCOMPARE(_masterController->missionController()->visualItems()->count(), 6);
}

void PlanMasterControllerTest::_testMissionModeSaveMetadata(void)
{
    QVERIFY(!_masterController->saveToJson().object().contains(PlanMasterController::kJsonMissionModeKey));

    _masterController->setMissionMode(QStringLiteral("seedSpreader"));
    QCOMPARE(_masterController->missionMode(), QStringLiteral("seedSpreader"));
    QCOMPARE(_masterController->saveToJson().object().value(PlanMasterController::kJsonMissionModeKey).toString(),
             QStringLiteral("seedSpreader"));
}

void PlanMasterControllerTest::_testMissionModeGalleryMetadata(void)
{
    QTemporaryDir planDirectory;
    QVERIFY(planDirectory.isValid());

    _masterController->setMissionMode(QStringLiteral("seedSpreader"));
    _masterController->saveToFile(planDirectory.filePath(QStringLiteral("tagged.plan")));

    QJsonObject legacyPlan = _masterController->saveToJson().object();
    legacyPlan.remove(PlanMasterController::kJsonMissionModeKey);
    QJsonObject legacyMission = legacyPlan.value(PlanMasterController::kJsonMissionObjectKey).toObject();
    QJsonObject legacySurvey;
    legacySurvey[QStringLiteral("type")] = QStringLiteral("ComplexItem");
    legacySurvey[QStringLiteral("complexItemType")] = QStringLiteral("survey");
    legacySurvey[QStringLiteral("polygon")] = QJsonArray{
        QJsonArray{47.0, 8.0},
        QJsonArray{47.001, 8.0},
        QJsonArray{47.001, 8.001},
    };
    legacyMission[QStringLiteral("items")] = QJsonArray{legacySurvey};
    legacyPlan[PlanMasterController::kJsonMissionObjectKey] = legacyMission;

    QFile legacyFile(planDirectory.filePath(QStringLiteral("legacy.plan")));
    QVERIFY(legacyFile.open(QIODevice::WriteOnly | QIODevice::Text));
    const QByteArray legacyBytes = QJsonDocument(legacyPlan).toJson();
    QCOMPARE(legacyFile.write(legacyBytes), static_cast<qint64>(legacyBytes.size()));
    legacyFile.close();

    const QVariantList planFiles = QGCFileDialogController::getPlanFileInfoList(
        planDirectory.path(), QStringList{QStringLiteral("*.plan")});
    QCOMPARE(planFiles.size(), 2);

    for (const QVariant &planFile : planFiles) {
        const QVariantMap metadata = planFile.toMap();
        if (metadata.value(QStringLiteral("fileName")).toString() == QStringLiteral("tagged.plan")) {
            QCOMPARE(metadata.value(QStringLiteral("missionMode")).toString(), QStringLiteral("seedSpreader"));
            QCOMPARE(metadata.value(QStringLiteral("missionModeInferred")).toBool(), false);
        } else if (metadata.value(QStringLiteral("fileName")).toString() == QStringLiteral("legacy.plan")) {
            QCOMPARE(metadata.value(QStringLiteral("missionMode")).toString(), QStringLiteral("routeMapping"));
            QCOMPARE(metadata.value(QStringLiteral("missionModeInferred")).toBool(), true);
        } else {
            QFAIL("Unexpected plan returned by gallery metadata scan");
        }
    }
}

void PlanMasterControllerTest::_testSprayerSettingsSaveLoad(void)
{
    QTemporaryDir planDirectory;
    QVERIFY(planDirectory.isValid());

    _masterController->setMissionMode(QStringLiteral("customMission"));
    _masterController->setSprayerSettings(true, 0.690, 1.000);

    const QJsonObject savedJson = _masterController->saveToJson().object();
    QVERIFY(savedJson.contains(PlanMasterController::kJsonSprayerSettingsKey));
    const QJsonObject sprayerJson = savedJson.value(PlanMasterController::kJsonSprayerSettingsKey).toObject();
    QCOMPARE(sprayerJson.value(PlanMasterController::kJsonSprayerEnabledKey).toBool(), true);
    QCOMPARE(sprayerJson.value(PlanMasterController::kJsonSprayerNozzleRateKey).toDouble(), 0.690);
    QCOMPARE(sprayerJson.value(PlanMasterController::kJsonSprayerPumpRateKey).toDouble(), 1.000);

    const QString planFile = planDirectory.filePath(QStringLiteral("sprayer.plan"));
    _masterController->saveToFile(planFile);
    _masterController->clearSprayerSettings();
    QVERIFY(!_masterController->sprayerConfigured());

    _masterController->loadFromFile(planFile);
    QVERIFY(_masterController->sprayerConfigured());
    QVERIFY(_masterController->sprayerEnabled());
    QCOMPARE(_masterController->sprayerNozzleRate(), 0.690);
    QCOMPARE(_masterController->sprayerPumpRate(), 1.000);
}

void PlanMasterControllerTest::_testSprayerSettingsDisabledWithRates(void)
{
    _masterController->setSprayerSettings(false, 0.690, 1.000);

    const QJsonObject savedJson = _masterController->saveToJson().object();
    QVERIFY(savedJson.contains(PlanMasterController::kJsonSprayerSettingsKey));
    const QJsonObject sprayerJson = savedJson.value(PlanMasterController::kJsonSprayerSettingsKey).toObject();
    QCOMPARE(sprayerJson.value(PlanMasterController::kJsonSprayerEnabledKey).toBool(), false);
    QCOMPARE(sprayerJson.value(PlanMasterController::kJsonSprayerNozzleRateKey).toDouble(), 0.690);
    QCOMPARE(sprayerJson.value(PlanMasterController::kJsonSprayerPumpRateKey).toDouble(), 1.000);
    QVERIFY(_masterController->sprayerConfigured());
    QVERIFY(!_masterController->sprayerEnabled());
}

void PlanMasterControllerTest::_testSprayerSettingsIntegerJsonLoad(void)
{
    QTemporaryDir planDirectory;
    QVERIFY(planDirectory.isValid());

    QJsonObject planJson = _masterController->saveToJson().object();
    QJsonObject sprayerJson;
    sprayerJson[PlanMasterController::kJsonSprayerEnabledKey] = true;
    sprayerJson[PlanMasterController::kJsonSprayerNozzleRateKey] = 1;
    sprayerJson[PlanMasterController::kJsonSprayerPumpRateKey] = 2;
    planJson[PlanMasterController::kJsonSprayerSettingsKey] = sprayerJson;

    const QString planFile = planDirectory.filePath(QStringLiteral("integer_rates.plan"));
    QFile file(planFile);
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Text));
    const QByteArray planBytes = QJsonDocument(planJson).toJson();
    QCOMPARE(file.write(planBytes), static_cast<qint64>(planBytes.size()));
    file.close();

    _masterController->clearSprayerSettings();
    _masterController->loadFromFile(planFile);
    QVERIFY(_masterController->sprayerConfigured());
    QVERIFY(_masterController->sprayerEnabled());
    QCOMPARE(_masterController->sprayerNozzleRate(), 1.000);
    QCOMPARE(_masterController->sprayerPumpRate(), 2.000);
}

void PlanMasterControllerTest::_testRouteMappingTelemetrySaveLoad(void)
{
    QTemporaryDir planDirectory;
    QVERIFY(planDirectory.isValid());

    _masterController->setMissionMode(QStringLiteral("agricultureSpraying"));
    _masterController->setRouteMappingTelemetry(9.144, 12.192, 6.096);

    const QJsonObject savedJson = _masterController->saveToJson().object();
    QVERIFY(savedJson.contains(PlanMasterController::kJsonRouteMappingTelemetryKey));
    const QJsonObject telemetryJson = savedJson.value(PlanMasterController::kJsonRouteMappingTelemetryKey).toObject();
    QCOMPARE(telemetryJson.value(PlanMasterController::kJsonRouteMappingTakeoffAltitudeKey).toDouble(), 9.144);
    QCOMPARE(telemetryJson.value(PlanMasterController::kJsonRouteMappingPatternAltitudeKey).toDouble(), 12.192);
    QCOMPARE(telemetryJson.value(PlanMasterController::kJsonRouteMappingPatternSpeedKey).toDouble(), 6.096);

    const QString planFile = planDirectory.filePath(QStringLiteral("route_mapping_telemetry.plan"));
    _masterController->saveToFile(planFile);
    _masterController->clearRouteMappingTelemetry();
    QVERIFY(!_masterController->routeMappingConfigured());

    _masterController->loadFromFile(planFile);
    QVERIFY(_masterController->routeMappingConfigured());
    QCOMPARE(_masterController->routeMappingTakeoffAltitudeMeters(), 9.144);
    QCOMPARE(_masterController->routeMappingPatternAltitudeMeters(), 12.192);
    QCOMPARE(_masterController->routeMappingPatternSpeedMps(), 6.096);
}

void PlanMasterControllerTest::_testActiveVehicleChanged(void) {
    // There was a defect where the PlanMasterController would, upon a new active vehicle,
    // overzelously disconnect all subscribers interested in the outgoing active vechicle.
    Vehicle* outgoingManagerVehicle = _masterController->managerVehicle();

    // spyMissionManager emulates a subscriber that should not be disconnected when
    // the active vehicle changes
    MultiSignalSpyV2 spyMissionManager;
    spyMissionManager.init(outgoingManagerVehicle->missionManager());
    MultiSignalSpyV2 spyMasterController;
    spyMasterController.init(_masterController);

    // Since MissionManager works with actual vehicles (which we don't have in the test cycle)
    // we have to be a bit creative emulating a signal emitted by a MissionManager.
    emit outgoingManagerVehicle->missionManager()->error(0,"");
    auto missionManagerErrorSignalMask = spyMissionManager.signalNameToMask("error");
    QVERIFY(spyMissionManager.checkOnlySignalByMask(missionManagerErrorSignalMask));
    spyMissionManager.clearSignal("error");
    QVERIFY(spyMissionManager.checkNoSignals());

    _connectMockLink(MAV_AUTOPILOT_PX4);
    auto masterControllerMgrVehicleChanged = spyMasterController.signalNameToMask("managerVehicleChanged");
    QVERIFY(spyMasterController.checkSignalByMask(masterControllerMgrVehicleChanged));

    emit outgoingManagerVehicle->missionManager()->error(0,"");
    // This signal was affected by the defect - it wouldn't reach the subscriber. Here
    // we make sure it does.
    QVERIFY(spyMissionManager.checkOnlySignalByMask(missionManagerErrorSignalMask));
}
