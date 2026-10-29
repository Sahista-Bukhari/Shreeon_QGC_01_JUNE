#include "QGCFileDownload.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QCryptographicHash>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QRegularExpression>
#include <QtCore/QStandardPaths>
#include <QtNetwork/QNetworkProxy>
#include <QtNetwork/QSslSocket>

QGC_LOGGING_CATEGORY(QGCFileDownloadLog, "Utilities.QGCFileDownload");

QGCFileDownload::QGCFileDownload(QObject *parent)
    : QObject(parent)
    , _networkManager(new QNetworkAccessManager(this))
{
    // qCDebug(QGCFileDownloadLog) << Q_FUNC_INFO << this;
}

QGCFileDownload::~QGCFileDownload()
{
    // qCDebug(QGCFileDownloadLog) << Q_FUNC_INFO << this;
}

void QGCFileDownload::setCache(QAbstractNetworkCache *cache)
{
    _networkManager->setCache(cache);
}

void QGCFileDownload::setIgnoreSSLErrorsIfNeeded(QNetworkReply &networkReply)
{
    Q_UNUSED(networkReply);

    // Intentionally a no-op. Older builds ignored NoPeerCertificate when the
    // Qt-linked OpenSSL major version differed from the runtime library. That
    // bypass disabled peer authentication and is unsafe for firmware downloads.
    const bool sslLibraryBuildIs1x = ((QSslSocket::sslLibraryBuildVersionNumber() & 0xf0000000) == 0x10000000);
    const bool sslLibraryIs3x = ((QSslSocket::sslLibraryVersionNumber() & 0xf0000000) == 0x30000000);
    if (sslLibraryBuildIs1x && sslLibraryIs3x) {
        qCWarning(QGCFileDownloadLog)
            << "OpenSSL major version mismatch (build 1.x / runtime 3.x). "
               "TLS certificate validation remains enforced; fix the OpenSSL install if downloads fail.";
    }
}

QString QGCFileDownload::serverContentMd5() const
{
    return _serverContentMd5;
}

bool QGCFileDownload::download(const QString &remoteFile, const QList<QPair<QNetworkRequest::Attribute,QVariant>> &requestAttributes, bool redirect)
{
    if (!redirect) {
        _requestAttributes = requestAttributes;
        _originalRemoteFile = remoteFile;
        _serverContentMd5.clear();
    }

    if (remoteFile.isEmpty()) {
        qCWarning(QGCFileDownloadLog) << "downloadFile empty";
        return false;
    }

    QUrl remoteUrl;
    if (remoteFile.startsWith("http:") || remoteFile.startsWith("https:")) {
        remoteUrl.setUrl(remoteFile);
    } else {
        // QNetworkRequest is used for local files too to use the same code path
        remoteUrl = QUrl::fromLocalFile(remoteFile);
    }

    if (!remoteUrl.isValid()) {
        qCWarning(QGCFileDownloadLog) << "Remote URL is invalid" << remoteFile;
        return false;
    }

    QNetworkRequest networkRequest(remoteUrl);
    for (const QPair<QNetworkRequest::Attribute,QVariant> &attribute : requestAttributes) {
        networkRequest.setAttribute(attribute.first, attribute.second);
    }

#if !defined(Q_OS_IOS) && !defined(Q_OS_ANDROID)
    QNetworkProxy tProxy = _networkManager->proxy();
    tProxy.setType(QNetworkProxy::DefaultProxy);
    _networkManager->setProxy(tProxy);
#endif

    QNetworkReply *const networkReply = _networkManager->get(networkRequest);
    if (!networkReply) {
        qCWarning(QGCFileDownloadLog) << "QNetworkAccessManager::get failed";
        return false;
    }

    (void) connect(networkReply, &QNetworkReply::downloadProgress, this, &QGCFileDownload::downloadProgress);
    (void) connect(networkReply, &QNetworkReply::finished, this, &QGCFileDownload::_downloadFinished);
    (void) connect(networkReply, &QNetworkReply::errorOccurred, this, &QGCFileDownload::_downloadError);

    return true;
}

void QGCFileDownload::_captureServerContentMd5(const QNetworkReply &reply)
{
    _serverContentMd5.clear();

    const QByteArray contentMd5Header = reply.rawHeader("Content-MD5");
    if (!contentMd5Header.isEmpty()) {
        const QByteArray decoded = QByteArray::fromBase64(contentMd5Header);
        if (decoded.size() == 16) {
            _serverContentMd5 = QString::fromLatin1(decoded.toHex());
            return;
        }
    }

    // Amazon S3 simple-object ETags are quoted MD5 hex digests.
    QString etag = reply.header(QNetworkRequest::ETagHeader).toString().trimmed();
    if (etag.startsWith(QLatin1Char('"')) && etag.endsWith(QLatin1Char('"')) && etag.size() >= 2) {
        etag = etag.mid(1, etag.size() - 2);
    }
    static const QRegularExpression simpleMd5(QStringLiteral("^[0-9a-fA-F]{32}$"));
    if (simpleMd5.match(etag).hasMatch()) {
        _serverContentMd5 = etag.toLower();
    }
}

bool QGCFileDownload::_verifyLocalFileMd5(const QString &localFile, const QString &expectedMd5, QString *errorMessage) const
{
    if (expectedMd5.isEmpty()) {
        return true;
    }

    QFile file(localFile);
    if (!file.open(QIODevice::ReadOnly)) {
        if (errorMessage) {
            *errorMessage = tr("Could not open downloaded file for integrity check: %1").arg(file.errorString());
        }
        return false;
    }

    QCryptographicHash hash(QCryptographicHash::Md5);
    if (!hash.addData(&file)) {
        if (errorMessage) {
            *errorMessage = tr("Failed hashing downloaded file for integrity check");
        }
        return false;
    }
    const QString actual = QString::fromLatin1(hash.result().toHex());
    if (actual.compare(expectedMd5, Qt::CaseInsensitive) != 0) {
        if (errorMessage) {
            *errorMessage = tr("Downloaded file failed MD5 integrity check (expected %1, got %2)")
                                .arg(expectedMd5, actual);
        }
        return false;
    }
    return true;
}

void QGCFileDownload::_downloadFinished()
{
    QNetworkReply *const reply = qobject_cast<QNetworkReply*>(QObject::sender());
    if (!reply) {
        return;
    }
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        return;
    }

    if (!reply->isOpen()) {
        return;
    }

    if (!reply->url().isLocalFile()) {
        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if ((statusCode < HTTP_Response::SUCCESS_OK) || (statusCode >= HTTP_Response::REDIRECTION_MULTIPLE_CHOICES)) {
            return;
        }
    }

    QVariant redirectionTarget = reply->attribute(QNetworkRequest::RedirectionTargetAttribute);
    if (!redirectionTarget.isNull()) {
        const QUrl redirectUrl = reply->url().resolved(redirectionTarget.toUrl());
        (void) download(redirectUrl.toString(), _requestAttributes, true);
        return;
    }

    _captureServerContentMd5(*reply);

    // Split out filename from path
    QString remoteFileName = QFileInfo(reply->url().toString()).fileName();
    if (remoteFileName.isEmpty()) {
        qCWarning(QGCFileDownloadLog) << "Unabled to parse filename from remote url" << reply->url().toString();
        remoteFileName = "DownloadedFile";
    }

    // Strip out http parameters from remote filename
    const int parameterIndex = remoteFileName.indexOf("?");
    if (parameterIndex != -1) {
        remoteFileName = remoteFileName.left(parameterIndex);
    }

    QString downloadFilename = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    if (downloadFilename.isEmpty()) {
        downloadFilename = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
        if (downloadFilename.isEmpty()) {
            emit downloadComplete(_originalRemoteFile, QString(), tr("Unabled to find writable download location. Tried downloads and temp directory."));
            return;
        }
    }
    downloadFilename += "/" + remoteFileName;

    if (!downloadFilename.isEmpty()) {
        // Store downloaded file in download location
        QFile file(downloadFilename);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            emit downloadComplete(_originalRemoteFile, downloadFilename, tr("Could not save downloaded file to %1. Error: %2").arg(downloadFilename, file.errorString()));
            return;
        }

        const QByteArray downloadedData = reply->readAll();
        const qint64 bytesWritten = file.write(downloadedData);
        const bool flushed = bytesWritten == downloadedData.size() && file.flush();
        const QString writeError = file.errorString();
        file.close();
        if (!flushed) {
            QFile::remove(downloadFilename);
            emit downloadComplete(
                _originalRemoteFile,
                QString(),
                tr("Could not completely save downloaded file to %1. Error: %2")
                    .arg(downloadFilename, writeError));
            return;
        }

        QString integrityError;
        if (!_verifyLocalFileMd5(downloadFilename, _serverContentMd5, &integrityError)) {
            QFile::remove(downloadFilename);
            emit downloadComplete(_originalRemoteFile, QString(), integrityError);
            return;
        }

        emit downloadComplete(_originalRemoteFile, downloadFilename, QString());
    } else {
        const QString errorMsg = "Internal error";
        qCWarning(QGCFileDownloadLog) << errorMsg;
        emit downloadComplete(_originalRemoteFile, downloadFilename, errorMsg);
    }
}

void QGCFileDownload::_downloadError(QNetworkReply::NetworkError code)
{
    QString errorMsg;

    switch (code) {
    case QNetworkReply::OperationCanceledError:
        errorMsg = tr("Download cancelled");
        break;
    case QNetworkReply::ContentNotFoundError:
        errorMsg = tr("Error: File Not Found");
        break;
    default:
        errorMsg = tr("Error during download. Error: %1").arg(code);
        break;
    }

    emit downloadComplete(_originalRemoteFile, QString(), errorMsg);
}
