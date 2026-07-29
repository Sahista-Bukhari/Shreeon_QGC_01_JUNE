#pragma once

#include "FactGroup.h"

#include <QtCore/QVector>

/// VehicleTankFactGroup
/// Decodes live tank weight from PX4 NAMED_VALUE_FLOAT messages and derives
/// spray flow rate from weight change over a short rolling time window.
///
/// MAVLink contract:
///   Message : MAVLINK_MSG_ID_NAMED_VALUE_FLOAT
///   Name    : "LC_WEIGHT"  (char name[10])
///   Value   : current tank weight in kg
///
/// Optional direct flow (if firmware publishes it):
///   Name    : "LC_FLOW"    value in L/min
///
/// QML access after Vehicle registration:
///   activeVehicle.tank.weightKg.rawValue
///   activeVehicle.tank.flowRateLpm.rawValue

class VehicleTankFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *weightKg    READ weightKg    CONSTANT)
    Q_PROPERTY(Fact *flowRateLpm READ flowRateLpm CONSTANT)

public:
    explicit VehicleTankFactGroup(QObject *parent = nullptr);

    Fact *weightKg()    { return &_weightKgFact; }
    Fact *flowRateLpm() { return &_flowRateLpmFact; }

    // Called by Vehicle for every incoming MAVLink message
    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) final;

protected:
    void _handleNamedValueFloat(const mavlink_message_t &message);
    void _updateFlowFromWeight(double weightKg);
    void _clearFlowHistory(double weightKg);
    void _setFlowLpm(double flowLpm);

    Fact _weightKgFact    = Fact(0, QStringLiteral("weightKg"),    FactMetaData::valueTypeDouble);
    Fact _flowRateLpmFact = Fact(0, QStringLiteral("flowRateLpm"), FactMetaData::valueTypeDouble);

    struct WeightSample {
        qint64 ms = 0;
        double kg = 0.0;
    };

    QVector<WeightSample> _weightHistory;
    bool                  _haveDirectFlow = false;
};
