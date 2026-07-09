#pragma once

#include "FactGroup.h"

/// VehicleTankFactGroup
/// Decodes live tank weight from PX4 NAMED_VALUE_FLOAT messages.
///
/// MAVLink contract:
///   Message : MAVLINK_MSG_ID_NAMED_VALUE_FLOAT
///   Name    : "LC_WEIGHT"  (char name[10])
///   Value   : current tank weight in kg
///
/// QML access after Vehicle registration:
///   activeVehicle.tank.weightKg.rawValue
class VehicleTankFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *weightKg READ weightKg CONSTANT)

public:
    explicit VehicleTankFactGroup(QObject *parent = nullptr);

    Fact *weightKg() { return &_weightKgFact; }

    // Called by Vehicle for every incoming MAVLink message
    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) final;

protected:
    void _handleNamedValueFloat(const mavlink_message_t &message);

    Fact _weightKgFact = Fact(0, QStringLiteral("weightKg"), FactMetaData::valueTypeDouble);
};
