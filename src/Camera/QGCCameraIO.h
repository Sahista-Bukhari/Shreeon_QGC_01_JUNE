#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QLoggingCategory>
#include <QtCore/QTimer>

#include <cstddef>

#include "MAVLinkLib.h"

class MavlinkCameraControl;
class Fact;
class Vehicle;

Q_DECLARE_LOGGING_CATEGORY(CameraIOLog)
Q_DECLARE_LOGGING_CATEGORY(CameraIOLogVerbose)

/// Camera parameter handler.
class QGCCameraParamIO : public QObject
{
public:
    QGCCameraParamIO(MavlinkCameraControl *control, Fact *fact, Vehicle *vehicle);
    ~QGCCameraParamIO();

    void handleParamAck(const mavlink_param_ext_ack_t &ack);
    void handleParamValue(const mavlink_param_ext_value_t &value);
    void setParamRequest();
    bool paramDone() const { return _done; }
    void paramRequest(bool reset = true);
    void sendParameter(bool updateUI = false);

    /// Safely copy custom/string parameter bytes into a fixed MAVLink param_value buffer.
    /// Copies min(source.size(), destCapacity) bytes. Overlong values are truncated.
    /// Caller must zero-initialize dest so unused trailing bytes remain zero.
    /// @return Number of bytes copied from source.
    static size_t copyCustomParamValue(uint8_t *dest, size_t destCapacity, const QByteArray &source);

private slots:
    void _paramWriteTimeout();
    void _paramRequestTimeout();
    void _factChanged(const QVariant &value);
    void _containerRawValueChanged(const QVariant &value);

private:
    void _sendParameter();
    QVariant _valueFromMessage(const char *value, uint8_t param_type);

    MavlinkCameraControl *_control = nullptr;
    Fact *_fact = nullptr;
    Vehicle *_vehicle = nullptr;

    bool _done = false;
    bool _forceUIUpdate = false;
    bool _paramRequestReceived = false;
    bool _updateOnSet = false;
    int _requestRetries = 0;
    int _sentRetries = 0;
    MAV_PARAM_EXT_TYPE _mavParamType = MAV_PARAM_EXT_TYPE_UINT8;
    QTimer _paramRequestTimer;
    QTimer _paramWriteTimer;
};
