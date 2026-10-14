#include "MissionControllerTest.h"
#include "MissionController.h"
#include "PlanMasterController.h"
#include "SimpleMissionItem.h"
#include "TakeoffMissionItem.h"
#include "MissionSettingsItem.h"
#include "MissionItem.h"
#include "SurveyComplexItem.h"
#include "SettingsManager.h"
#include "AppSettings.h"
#include "PlanViewSettings.h"
#include "MultiSignalSpy.h"

#include <QtTest/QTest>

MissionControllerTest::MissionControllerTest(void)
{

}

void MissionControllerTest::cleanup(void)
{
    delete _masterController;
    delete _multiSpyMissionController;
    delete _multiSpyMissionItem;

    _masterController           = nullptr;
    _missionController          = nullptr;
    _multiSpyMissionController  = nullptr;
    _multiSpyMissionItem        = nullptr;

    MissionControllerManagerTest::cleanup();
}

void MissionControllerTest::_initForFirmwareType(MAV_AUTOPILOT firmwareType)
{
    MissionControllerManagerTest::_initForFirmwareType(firmwareType);

    // VisualMissionItem signals
    _rgVisualItemSignals[coordinateChangedSignalIndex] = SIGNAL(coordinateChanged(const QGeoCoordinate&));

    // MissionController signals
    _rgMissionControllerSignals[visualItemsChangedSignalIndex] =    SIGNAL(visualItemsChanged());

    // Master controller pulls offline vehicle info from settings
    SettingsManager::instance()->appSettings()->offlineEditingFirmwareClass()->setRawValue(QGCMAVLink::firmwareClass(firmwareType));
    _masterController = new PlanMasterController(this);
    _masterController->setFlyView(false);
    _missionController = _masterController->missionController();

    _multiSpyMissionController = new MultiSignalSpy();
    Q_CHECK_PTR(_multiSpyMissionController);
    QCOMPARE(_multiSpyMissionController->init(_missionController, _rgMissionControllerSignals, _cMissionControllerSignals), true);

    _masterController->start();

    // All signals should some through on start
    QCOMPARE(_multiSpyMissionController->checkOnlySignalsByMask(visualItemsChangedSignalMask), true);
    _multiSpyMissionController->clearAllSignals();

    QmlObjectListModel* visualItems = _missionController->visualItems();
    QVERIFY(visualItems);

    // Empty vehicle only has home position
    QCOMPARE(visualItems->count(), 1);

    // Mission Settings should be in first slot
    MissionSettingsItem* settingsItem = visualItems->value<MissionSettingsItem*>(0);
    QVERIFY(settingsItem);

    // Offline vehicle, so no home position
    QCOMPARE(settingsItem->coordinate().isValid(), false);

    // Empty mission, so no child items possible
    QCOMPARE(settingsItem->childItems()->count(), 0);

    // No waypoint lines
    QmlObjectListModel* simpleFlightPathSegments = _missionController->simpleFlightPathSegments();
    QVERIFY(simpleFlightPathSegments);
    QCOMPARE(simpleFlightPathSegments->count(), 0);
}

void MissionControllerTest::_testEmptyVehicleWorker(MAV_AUTOPILOT firmwareType)
{
    _initForFirmwareType(firmwareType);

    // FYI: A significant amount of empty vehicle testing is in _initForFirmwareType since that
    // sets up an empty vehicle

    QmlObjectListModel* visualItems = _missionController->visualItems();
    QVERIFY(visualItems);
    VisualMissionItem* visualItem = visualItems->value<VisualMissionItem*>(0);
    QVERIFY(visualItem);

    _setupVisualItemSignals(visualItem);
}

void MissionControllerTest::_testEmptyVehiclePX4(void)
{
    _testEmptyVehicleWorker(MAV_AUTOPILOT_PX4);
}

void MissionControllerTest::_testEmptyVehicleAPM(void)
{
    _testEmptyVehicleWorker(MAV_AUTOPILOT_ARDUPILOTMEGA);
}

#if 0
void MissionControllerTest::_testOfflineToOnlineWorker(MAV_AUTOPILOT firmwareType)
{
    // Start offline and add item
    _missionController = new MissionController();
    Q_CHECK_PTR(_missionController);
    _missionController->start(false /* flyView */);
    _missionController->insertSimpleMissionItem(QGeoCoordinate(37.803784, -122.462276), _missionController->visualItems()->count());

    // Go online to empty vehicle
    MissionControllerManagerTest::_initForFirmwareType(firmwareType);

#if 1
    // Due to current limitations, offline items will go away
    QCOMPARE(_missionController->visualItems()->count(), 1);
#else
    //Make sure our offline mission items are still there
    QCOMPARE(_missionController->visualItems()->count(), 2);
#endif
}

void MissionControllerTest::_testOfflineToOnlineAPM(void)
{
    _testOfflineToOnlineWorker(MAV_AUTOPILOT_ARDUPILOTMEGA);
}

void MissionControllerTest::_testOfflineToOnlinePX4(void)
{
    _testOfflineToOnlineWorker(MAV_AUTOPILOT_PX4);
}
#endif

void MissionControllerTest::_setupVisualItemSignals(VisualMissionItem* visualItem)
{
    delete _multiSpyMissionItem;

    _multiSpyMissionItem = new MultiSignalSpy();
    Q_CHECK_PTR(_multiSpyMissionItem);
    QCOMPARE(_multiSpyMissionItem->init(visualItem, _rgVisualItemSignals, _cVisualItemSignals), true);
}

void MissionControllerTest::_testGimbalRecalc(void)
{
    _initForFirmwareType(MAV_AUTOPILOT_PX4);
    _missionController->insertSimpleMissionItem(QGeoCoordinate(0, 0), 1);
    _missionController->insertSimpleMissionItem(QGeoCoordinate(0, 0), 2);
    _missionController->insertSimpleMissionItem(QGeoCoordinate(0, 0), 3);
    _missionController->insertSimpleMissionItem(QGeoCoordinate(0, 0), 4);

    // No specific gimbal yaw set yet
    for (int i=1; i<_missionController->visualItems()->count(); i++) {
        VisualMissionItem* visualItem = _missionController->visualItems()->value<VisualMissionItem*>(i);
        QVERIFY(qIsNaN(visualItem->missionGimbalYaw()));
    }

    // Specify gimbal yaw on settings item should generate yaw on all subsequent items
    const int yawIndex = 2;
    SimpleMissionItem* item = _missionController->visualItems()->value<SimpleMissionItem*>(yawIndex);
    item->cameraSection()->setSpecifyGimbal(true);
    item->cameraSection()->gimbalYaw()->setRawValue(0.0);
    SettingsManager::instance()->planViewSettings()->showGimbalOnlyWhenSet()->setRawValue(false);
    QTest::qWait(500); // Recalcs in MissionController are queued to remove dups. Allow return to main message loop.
    for (int i=1; i<_missionController->visualItems()->count(); i++) {
        //qDebug() << i;
        VisualMissionItem* visualItem = _missionController->visualItems()->value<VisualMissionItem*>(i);
        if (i >= yawIndex) {
            QCOMPARE(visualItem->missionGimbalYaw(), 0.0);
        } else {
            QVERIFY(qIsNaN(visualItem->missionGimbalYaw()));
        }
    }
}

void MissionControllerTest::_testVehicleYawRecalc(void)
{
    _initForFirmwareType(MAV_AUTOPILOT_PX4);

    double wpDistance   = 1000;
    double wpAngleInc   = 45;
    double wpAngle      = 0;

    int cMissionItems = 4;
    QGeoCoordinate currentCoord(0, 0);
    _missionController->insertSimpleMissionItem(currentCoord, 1);
    for (int i=2; i<=cMissionItems; i++) {
        wpAngle += wpAngleInc;
        currentCoord = currentCoord.atDistanceAndAzimuth(wpDistance, wpAngle);
        _missionController->insertSimpleMissionItem(currentCoord, i);
    }

    QTest::qWait(500); // Recalcs in MissionController are queued to remove dups. Allow return to main message loop.

    // No specific vehicle yaw set yet. Vehicle yaw should track flight path.
    double expectedVehicleYaw = wpAngleInc;
    for (int i=2; i<cMissionItems; i++) {
        //qDebug() << i;
        VisualMissionItem* visualItem = _missionController->visualItems()->value<VisualMissionItem*>(i);
        QCOMPARE(visualItem->missionVehicleYaw(), expectedVehicleYaw);
        if (i <= cMissionItems - 1) {
            expectedVehicleYaw += wpAngleInc;
        }
    }

    SimpleMissionItem* simpleItem = _missionController->visualItems()->value<SimpleMissionItem*>(3);
    simpleItem->missionItem().setParam4(66);

    QTest::qWait(500); // Recalcs in MissionController are queued to remove dups. Allow return to main message loop.

    // All item should track vehicle path except for the one changed
    expectedVehicleYaw = wpAngleInc;
    for (int i=2; i<cMissionItems; i++) {
        //qDebug() << i;
        VisualMissionItem* visualItem = _missionController->visualItems()->value<VisualMissionItem*>(i);
        QCOMPARE(visualItem->missionVehicleYaw(), i == 3 ? 66.0 : expectedVehicleYaw);
        if (i <= cMissionItems - 1) {
            expectedVehicleYaw += wpAngleInc;
        }
    }
}

void MissionControllerTest::_testLoadJsonSectionAvailable(void)
{
    _initForFirmwareType(MAV_AUTOPILOT_PX4);
    _masterController->loadFromFile(":/unittest/SectionTest.plan");

    QmlObjectListModel* visualItems = _missionController->visualItems();
    QVERIFY(visualItems);
    QCOMPARE(visualItems->count(), 5);

    // Check that only waypoint items have camera and speed sections
    for (int i=1; i<visualItems->count(); i++) {
        SimpleMissionItem* item = visualItems->value<SimpleMissionItem*>(i);
        QVERIFY(item);
        if ((int)item->command() == MAV_CMD_NAV_WAYPOINT) {
            QCOMPARE(item->cameraSection()->available(), true);
            QCOMPARE(item->speedSection()->available(), true);
        } else {
            QCOMPARE(item->cameraSection()->available(), false);
            QCOMPARE(item->speedSection()->available(), false);
        }

    }
}

void MissionControllerTest::_testLoadBaylandsMappingPlan(void)
{
    _initForFirmwareType(MAV_AUTOPILOT_PX4);

    const QString planFile = QFINDTESTDATA("../../demo/BaylandsRouteMapping.plan");
    QVERIFY2(!planFile.isEmpty(), "Baylands route-mapping demo plan was not found");
    _masterController->loadFromFile(planFile);

    QmlObjectListModel* visualItems = _missionController->visualItems();
    QVERIFY(visualItems);
    // Camera mode is folded into MissionSettingsItem during plan load.
    QCOMPARE(visualItems->count(), 4);

    SurveyComplexItem* surveyItem = nullptr;
    for (int i = 0; i < visualItems->count(); i++) {
        surveyItem = qobject_cast<SurveyComplexItem*>(visualItems->get(i));
        if (surveyItem) {
            break;
        }
    }

    QVERIFY(surveyItem);
    QVERIFY(surveyItem->surveyAreaPolygon()->isValid());
    QCOMPARE(surveyItem->cameraShots(), 31);
    QCOMPARE(surveyItem->cameraCalc()->adjustedFootprintSide()->rawValue().toDouble(), 25.0);
    QCOMPARE(surveyItem->cameraCalc()->adjustedFootprintFrontal()->rawValue().toDouble(), 25.0);
    QCOMPARE(surveyItem->cameraTriggerInTurnAround()->rawValue().toBool(), false);
    QCOMPARE(surveyItem->photoCaptureTransectPoints().count(), 12);

    // The flight mission must start distance-based capture automatically at
    // each resumable transect entry, take the first image immediately, and stop
    // at pattern exit.
    QObject missionItemParent;
    QList<MissionItem*> missionItems;
    surveyItem->appendMissionItems(missionItems, &missionItemParent);

    int captureStartCount = 0;
    int captureStopCount = 0;
    for (const MissionItem* missionItem : std::as_const(missionItems)) {
        if (missionItem->command() != MAV_CMD_DO_SET_CAM_TRIGG_DIST) {
            continue;
        }
        if (missionItem->param1() > 0) {
            captureStartCount++;
            QCOMPARE(missionItem->param1(), 25.0);
            QCOMPARE(missionItem->param3(), 1.0);
        } else {
            captureStopCount++;
            // The stop command takes the required endpoint image immediately.
            QCOMPARE(missionItem->param3(), 1.0);
        }
    }
    QCOMPARE(captureStartCount, 6);
    QCOMPARE(captureStopCount, 6);
}

void MissionControllerTest::_testRouteMappingAltitudeProfile_data(void)
{
    QTest::addColumn<double>("altitudeMeters");
    QTest::addColumn<double>("triggerDistanceMeters");

    QTest::newRow("high-resolution") << 30.0 << 6.0;
    QTest::newRow("low-resolution") << 60.0 << 9.0;
}

void MissionControllerTest::_testRouteMappingAltitudeProfile(void)
{
    QFETCH(double, altitudeMeters);
    QFETCH(double, triggerDistanceMeters);

    _initForFirmwareType(MAV_AUTOPILOT_PX4);

    const QGeoCoordinate launchCoordinate(47.63355064, -122.08982199);
    auto* takeoffItem = qobject_cast<TakeoffMissionItem*>(
        _missionController->insertTakeoffItem(launchCoordinate, -1, false));
    QVERIFY(takeoffItem);

    auto* surveyItem = qobject_cast<SurveyComplexItem*>(
        _missionController->insertComplexMissionItem(
            _missionController->surveyComplexItemName(), launchCoordinate, -1, false));
    QVERIFY(surveyItem);

    constexpr double edgeDistanceMeters = 100.0;
    QList<QGeoCoordinate> polygonVertices;
    polygonVertices << launchCoordinate
                    << launchCoordinate.atDistanceAndAzimuth(edgeDistanceMeters, 90.0)
                    << launchCoordinate.atDistanceAndAzimuth(edgeDistanceMeters, 135.0)
                    << launchCoordinate.atDistanceAndAzimuth(edgeDistanceMeters, 180.0);
    surveyItem->surveyAreaPolygon()->appendVertices(polygonVertices);

    // This is the Route Mapping preset contract. The defect was caused by
    // updating only DistanceToSurface while NAV_TAKEOFF retained the global
    // 50 m default. Both Facts must be aligned before mission flattening.
    surveyItem->cameraCalc()->setDistanceMode(QGroundControlQmlGlobal::AltitudeModeRelative);
    surveyItem->cameraCalc()->valueSetIsDistance()->setRawValue(true);
    surveyItem->cameraCalc()->distanceToSurface()->setRawValue(altitudeMeters);
    surveyItem->cameraCalc()->adjustedFootprintFrontal()->setRawValue(triggerDistanceMeters);
    takeoffItem->altitude()->setRawValue(altitudeMeters);

    QObject missionItemParent;
    QList<MissionItem*> missionItems;
    for (int i = 0; i < _missionController->visualItems()->count(); ++i) {
        auto* visualItem = _missionController->visualItems()->value<VisualMissionItem*>(i);
        QVERIFY(visualItem);
        visualItem->appendMissionItems(missionItems, &missionItemParent);
    }

    int takeoffCount = 0;
    int surveyCoordinateCount = 0;
    bool takeoffSeen = false;
    for (const MissionItem* missionItem : std::as_const(missionItems)) {
        if (missionItem->command() == MAV_CMD_NAV_TAKEOFF) {
            QCOMPARE(missionItem->frame(), MAV_FRAME_GLOBAL_RELATIVE_ALT);
            QCOMPARE(missionItem->param7(), altitudeMeters);
            takeoffSeen = true;
            ++takeoffCount;
            continue;
        }

        if (takeoffSeen && (missionItem->command() == MAV_CMD_NAV_WAYPOINT
                            || missionItem->command() == MAV_CMD_CONDITION_GATE)) {
            QCOMPARE(missionItem->frame(), MAV_FRAME_GLOBAL_RELATIVE_ALT);
            QCOMPARE(missionItem->param7(), altitudeMeters);
            ++surveyCoordinateCount;
        }
    }

    QCOMPARE(takeoffCount, 1);
    QVERIFY(surveyCoordinateCount > 0);
}

void MissionControllerTest::_testGlobalAltMode(void)
{
    _initForFirmwareType(MAV_AUTOPILOT_PX4);

    struct  _globalAltMode_s {
        QGroundControlQmlGlobal::AltMode   altMode;
        MAV_FRAME                               expectedMavFrame;
    } altModeTestCases[] = {
        { QGroundControlQmlGlobal::AltitudeModeRelative,            MAV_FRAME_GLOBAL_RELATIVE_ALT },
        { QGroundControlQmlGlobal::AltitudeModeAbsolute,            MAV_FRAME_GLOBAL },
        { QGroundControlQmlGlobal::AltitudeModeCalcAboveTerrain,    MAV_FRAME_GLOBAL },
        { QGroundControlQmlGlobal::AltitudeModeTerrainFrame,        MAV_FRAME_GLOBAL_TERRAIN_ALT },
    };

    for (const _globalAltMode_s& testCase: altModeTestCases) {
        _missionController->removeAll();
        _missionController->setGlobalAltitudeMode(testCase.altMode);

        _missionController->insertTakeoffItem(QGeoCoordinate(0, 0), 1);
        _missionController->insertSimpleMissionItem(QGeoCoordinate(0, 0), 2);
        _missionController->insertSimpleMissionItem(QGeoCoordinate(0, 0), 3);
        _missionController->insertSimpleMissionItem(QGeoCoordinate(0, 0), 4);

        SimpleMissionItem* si = qobject_cast<SimpleMissionItem*>(_missionController->visualItems()->value<VisualMissionItem*>(1));
        QCOMPARE(si->altitudeMode(), QGroundControlQmlGlobal::AltitudeModeRelative);
        QCOMPARE(si->missionItem().frame(), MAV_FRAME_GLOBAL_RELATIVE_ALT);

        for (int i=2; i<_missionController->visualItems()->count(); i++) {
            qDebug() << i;
            SimpleMissionItem* si = qobject_cast<SimpleMissionItem*>(_missionController->visualItems()->value<VisualMissionItem*>(i));
            QCOMPARE(si->altitudeMode(), testCase.altMode);
            QCOMPARE(si->missionItem().frame(), testCase.expectedMavFrame);
        }
    }
}
