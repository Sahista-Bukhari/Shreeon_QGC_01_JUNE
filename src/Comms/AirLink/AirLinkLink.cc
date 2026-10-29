#include "AirLinkLink.h"
#include "AppSettings.h"
#include "MAVLinkProtocol.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"

#include <QtCore/QSettings>
#include <QtCore/QTimer>
#include <QtNetwork/QUdpSocket>

#include <cstring>

QGC_LOGGING_CATEGORY(AirLinkLinkLog, "AirLink.AirLinkLink");

namespace {
bool copyAirLinkCredentialField(char *dest, size_t destCapacity, const QByteArray &utf8, const char *fieldName)
{
    // MAVLink fixed char[N] fields must remain within capacity. Keep one byte for
    // an explicit trailing NUL so pack helpers that treat the buffer as a C string
    // cannot read past the field.
    if (!dest || destCapacity == 0) {
        return false;
    }
    if (static_cast<size_t>(utf8.size()) >= destCapacity) {
        qCWarning(AirLinkLinkLog)
            << "AirLink" << fieldName << "UTF-8 length" << utf8.size()
            << "exceeds MAVLink field capacity" << (destCapacity - 1);
        return false;
    }
    (void) memset(dest, 0, destCapacity);
    if (!utf8.isEmpty()) {
        (void) memcpy(dest, utf8.constData(), static_cast<size_t>(utf8.size()));
    }
    return true;
}
} // namespace

/*===========================================================================*/

AirLinkConfiguration::AirLinkConfiguration(const QString &name, QObject *parent)
    : UDPConfiguration(name)
{
    // qCDebug(AirLinkLinkLog) << Q_FUNC_INFO << this;
}

AirLinkConfiguration::AirLinkConfiguration(const AirLinkConfiguration *copy, QObject *parent)
    : UDPConfiguration(copy)
{
    // qCDebug(AirLinkLinkLog) << Q_FUNC_INFO << this;

    AirLinkConfiguration::copyFrom(copy);
}

AirLinkConfiguration::~AirLinkConfiguration()
{
    // qCDebug(AirLinkLinkLog) << Q_FUNC_INFO << this;
}

void AirLinkConfiguration::copyFrom(const LinkConfiguration *source)
{
    Q_ASSERT(source);

    const UDPConfiguration *const udpSource = qobject_cast<const UDPConfiguration*>(source);
    Q_ASSERT(udpSource);
    UDPConfiguration::copyFrom(udpSource);

    const AirLinkConfiguration *const airLinkSource = qobject_cast<const AirLinkConfiguration*>(source);
    Q_ASSERT(airLinkSource);

    setUsername(airLinkSource->username());
    setPassword(airLinkSource->password());
    setModemName(airLinkSource->modemName());
}

void AirLinkConfiguration::loadSettings(QSettings &settings, const QString &root)
{
    AppSettings *const appSettings = SettingsManager::instance()->appSettings();

    settings.beginGroup(root);

    setUsername(settings.value(_usernameSettingsKey, appSettings->loginAirLink()->rawValueString()).toString());
    // Passwords are kept in memory only. Drop any legacy plaintext value that
    // older builds may have written into QSettings.
    if (settings.contains(_passwordSettingsKey)) {
        settings.remove(_passwordSettingsKey);
    }
    setPassword(QString());
    setModemName(settings.value(_modemNameSettingsKey).toString());

    settings.endGroup();
}

void AirLinkConfiguration::saveSettings(QSettings &settings, const QString &root) const
{
    settings.beginGroup(root);

    settings.setValue(_usernameSettingsKey, _username);
    // Never persist AirLink passwords in QSettings. Prefer an OS credential
    // store when one is wired up; until then require the user to re-enter.
    settings.remove(_passwordSettingsKey);
    settings.setValue(_modemNameSettingsKey, _modemName);

    settings.endGroup();
}

void AirLinkConfiguration::setUsername(const QString &username)
{
    if (username != _username) {
        _username = username;
        emit usernameChanged();
    }
}

void AirLinkConfiguration::setPassword(const QString &password)
{
    if (password != _password) {
        _password = password;
        emit passwordChanged();
    }
}

void AirLinkConfiguration::setModemName(const QString &modemName)
{
    if (modemName != _modemName) {
        _modemName = modemName;
        emit modemNameChanged();
    }
}

/*===========================================================================*/

AirLinkLink::AirLinkLink(SharedLinkConfigurationPtr &config, QObject *parent)
    : UDPLink(config)
    , _airLinkConfig(qobject_cast<const AirLinkConfiguration*>(config.get()))
{
    // qCDebug(AirLinkLinkLog) << Q_FUNC_INFO << this;

    _configureUdpSettings();
}

AirLinkLink::~AirLinkLink()
{
    // qCDebug(AirLinkLinkLog) << Q_FUNC_INFO << this;
}

bool AirLinkLink::_connect()
{
    std::shared_ptr<QMetaObject::Connection> conn = std::make_shared<QMetaObject::Connection>();
    *conn = connect(MAVLinkProtocol::instance(), &MAVLinkProtocol::messageReceived, this, [this, conn] (const LinkInterface* linkSrc, const mavlink_message_t &message) {
        if (this != linkSrc || message.msgid != MAVLINK_MSG_ID_AIRLINK_AUTH_RESPONSE) {
            return;
        }

        mavlink_airlink_auth_response_t responseMsg{};
        mavlink_msg_airlink_auth_response_decode(&message, &responseMsg);
        const int answer = responseMsg.resp_type;
        if (answer != AIRLINK_AUTH_RESPONSE_TYPE::AIRLINK_AUTH_OK) {
            qCDebug(AirLinkLinkLog) << "AirLink auth failed";
            return;
        }

        qCDebug(AirLinkLinkLog) << "Connected successfully";
        (void) QObject::disconnect(*conn);
        _setConnectFlag(false);
    });

    _setConnectFlag(true);

    QTimer *const pendingTimer = new QTimer();
    (void) connect(pendingTimer, &QTimer::timeout, this, [this, pendingTimer] {
        pendingTimer->setInterval(3000);
        if (_stillConnecting()) {
            qCDebug(AirLinkLinkLog) << "Connecting...";
            _sendLoginMsgToAirLink();
        } else {
            qCDebug(AirLinkLinkLog) << "Stopping...";
            pendingTimer->stop();
            pendingTimer->deleteLater();
        }
    }, Qt::QueuedConnection);
    pendingTimer->start(0);

    return UDPLink::_connect();
}

void AirLinkLink::disconnect()
{
    _setConnectFlag(false);
    (void) UDPLink::disconnect();
}

void AirLinkLink::_configureUdpSettings()
{
    quint16 availablePort = 14550;
    QUdpSocket udpSocket;
    while (!udpSocket.bind(QHostAddress::LocalHost, availablePort)) {
        availablePort++;
    }

    UDPConfiguration *const udpConfig = dynamic_cast<UDPConfiguration*>(UDPLink::_config.get());
    udpConfig->addHost(_airLinkHost, _airLinkPort);
    udpConfig->setLocalPort(availablePort);
    udpConfig->setDynamic(false);
}

void AirLinkLink::_sendLoginMsgToAirLink()
{
    mavlink_airlink_auth_t auth{};

    const QString login = _airLinkConfig->modemName(); ///< Connect not to account but to specific modem
    const QString pass = _airLinkConfig->password();
    const QByteArray loginUtf8 = login.toUtf8();
    const QByteArray passUtf8 = pass.toUtf8();

    if (!copyAirLinkCredentialField(
            auth.login,
            MAVLINK_MSG_AIRLINK_AUTH_FIELD_LOGIN_LEN,
            loginUtf8,
            "login")
        || !copyAirLinkCredentialField(
            auth.password,
            MAVLINK_MSG_AIRLINK_AUTH_FIELD_PASSWORD_LEN,
            passUtf8,
            "password")) {
        const QString error = tr(
            "AirLink login or password is too long for the MAVLink auth fields "
            "(max %1 UTF-8 bytes each). Shorten the credential and try again.")
                                  .arg(MAVLINK_MSG_AIRLINK_AUTH_FIELD_LOGIN_LEN - 1);
        qCWarning(AirLinkLinkLog) << error;
        emit communicationError(tr("AirLink Authentication"), error);
        _setConnectFlag(false);
        return;
    }

    mavlink_message_t mavmsg{};
    (void) mavlink_msg_airlink_auth_pack(0, 0, &mavmsg, auth.login, auth.password);

    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    const uint16_t len = mavlink_msg_to_send_buffer(buffer, &mavmsg);
    if (!_stillConnecting()) {
        qCDebug(AirLinkLinkLog) << "Force exit from connection";
        return;
    }

    writeBytesThreadSafe(reinterpret_cast<const char*>(buffer), len);
}

bool AirLinkLink::_stillConnecting()
{
    QMutexLocker locker(&_mutex);
    return _needToConnect;
}

void AirLinkLink::_setConnectFlag(bool connect)
{
    QMutexLocker locker(&_mutex);
    _needToConnect = connect;
}
