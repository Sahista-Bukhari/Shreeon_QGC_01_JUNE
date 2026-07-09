#include "VehicleTankFactGroup.h"
#include "Vehicle.h"

#include <limits>

VehicleTankFactGroup::VehicleTankFactGroup(QObject *parent)
    : FactGroup(1000, QStringLiteral(":/json/Vehicle/TankFact.json"), parent)
{
    _addFact(&_weightKgFact);

    // NaN until first LC_WEIGHT message is received
    _weightKgFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
}

void VehicleTankFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    switch (message.msgid) {
    case MAVLINK_MSG_ID_NAMED_VALUE_FLOAT:
        _handleNamedValueFloat(message);
        break;
    default:
        break;
    }
}

void VehicleTankFactGroup::_handleNamedValueFloat(const mavlink_message_t &message)
{
    mavlink_named_value_float_t value{};
    mavlink_msg_named_value_float_decode(&message, &value);

    // PX4 publishes tank volume/weight on the LC_WEIGHT named value
    if (QString(value.name) == QStringLiteral("LC_WEIGHT")) {
        _weightKgFact.setRawValue(value.value);
        _setTelemetryAvailable(true);
    }
}
