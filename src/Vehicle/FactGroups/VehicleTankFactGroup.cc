#include "VehicleTankFactGroup.h"
#include "Vehicle.h"

#include <QtCore/QDateTime>
#include <QtCore/QtGlobal>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>

namespace {
// Agricultural spray ceiling — anything above this from weight delta is a sensor jump, not spray.
constexpr double kMaxPlausibleFlowLpm = 40.0;
// Prefer ~0.6s of history so slow spray still produces a measurable delta quickly.
constexpr qint64 kFlowWindowMs = 600;
// Keep a little extra history for the lookup.
constexpr qint64 kHistoryKeepMs = 2000;
// Minimum window before publishing a derived rate (faster first reading).
constexpr qint64 kMinWindowMs = 250;
// Ignore tiny net change over the window (sensor noise).
constexpr double kMinWindowDeltaKg = 0.005;
}

VehicleTankFactGroup::VehicleTankFactGroup(QObject *parent)
    // 0 = emit Fact valueChanged immediately (no UI throttle delay)
    : FactGroup(0, QStringLiteral(":/json/Vehicle/TankFact.json"), parent)
{
    _addFact(&_weightKgFact);
    _addFact(&_flowRateLpmFact);

    _weightKgFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _flowRateLpmFact.setRawValue(0.0);
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

    const QString name = QString::fromLatin1(value.name, static_cast<int>(strnlen(value.name, sizeof(value.name))));

    // Direct flow rate from firmware (L/min), if published
    if (name == QStringLiteral("LC_FLOW") || name == QStringLiteral("FLOW_RATE")) {
        _haveDirectFlow = true;
        _setFlowLpm(std::max(0.0, static_cast<double>(value.value)));
        _setTelemetryAvailable(true);
        return;
    }

    // PX4 publishes tank volume/weight on the LC_WEIGHT named value
    if (name == QStringLiteral("LC_WEIGHT")) {
        _weightKgFact.setRawValue(value.value);
        if (!_haveDirectFlow) {
            _updateFlowFromWeight(static_cast<double>(value.value));
        }
        _setTelemetryAvailable(true);
    }
}

void VehicleTankFactGroup::_setFlowLpm(double flowLpm)
{
    // Always publish a finite value so QML never sees undefined.
    if (!qIsFinite(flowLpm) || flowLpm < 0.0) {
        flowLpm = 0.0;
    }
    flowLpm = std::min(flowLpm, kMaxPlausibleFlowLpm);
    _flowRateLpmFact.setRawValue(flowLpm);
}

void VehicleTankFactGroup::_clearFlowHistory(double weightKg)
{
    _weightHistory.clear();
    if (qIsFinite(weightKg)) {
        _weightHistory.append({QDateTime::currentMSecsSinceEpoch(), weightKg});
    }
    _setFlowLpm(0.0);
}

void VehicleTankFactGroup::_updateFlowFromWeight(double weightKg)
{
    if (!qIsFinite(weightKg)) {
        return;
    }

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    _weightHistory.append({nowMs, weightKg});

    // Drop old samples
    while (_weightHistory.size() > 1 && (nowMs - _weightHistory.first().ms) > kHistoryKeepMs) {
        _weightHistory.removeFirst();
    }

    if (_weightHistory.size() < 2) {
        _setFlowLpm(0.0);
        return;
    }

    // Instant fill / upward jump vs newest previous sample → clear immediately
    const WeightSample &prev = _weightHistory.at(_weightHistory.size() - 2);
    if (weightKg > prev.kg + 0.05) {
        _clearFlowHistory(weightKg);
        return;
    }

    // Find sample closest to (now - kFlowWindowMs), but at least kMinWindowMs old
    const qint64 targetMs = nowMs - kFlowWindowMs;
    int refIndex = -1;
    qint64 bestError = std::numeric_limits<qint64>::max();
    for (int i = 0; i < _weightHistory.size() - 1; ++i) {
        const qint64 ageMs = nowMs - _weightHistory.at(i).ms;
        if (ageMs < kMinWindowMs) {
            continue;
        }
        const qint64 error = std::abs(_weightHistory.at(i).ms - targetMs);
        if (error < bestError) {
            bestError = error;
            refIndex = i;
        }
    }

    // Not enough history yet — wait for the short window (typically < 0.3s)
    if (refIndex < 0) {
        return;
    }

    const WeightSample &ref = _weightHistory.at(refIndex);
    const double dtSec = (nowMs - ref.ms) / 1000.0;
    if (dtSec < (kMinWindowMs / 1000.0)) {
        return;
    }

    const double deltaKg = ref.kg - weightKg; // positive while emptying

    // Net fill over the window
    if (deltaKg < 0.0) {
        _setFlowLpm(0.0);
        return;
    }

    // Noise floor over the window
    if (deltaKg < kMinWindowDeltaKg) {
        _setFlowLpm(0.0);
        return;
    }

    const double instantLpm = (deltaKg / dtSec) * 60.0;

    // Discontinuity / dump glitch over the window
    if (instantLpm > kMaxPlausibleFlowLpm || deltaKg > 1.5) {
        _clearFlowHistory(weightKg);
        return;
    }

    // No heavy EMA — publish the windowed rate directly for low latency
    _setFlowLpm(instantLpm);
}
