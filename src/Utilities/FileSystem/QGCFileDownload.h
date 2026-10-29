#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

class QNetworkAccessManager;
class QAbstractNetworkCache;

Q_DECLARE_LOGGING_CATEGORY(QGCFileDownloadLog)

class QGCFileDownload : public QObject
{
    Q_OBJECT

    enum HTTP_Response {
        SUCCESS_OK = 200,
        REDIRECTION_MULTIPLE_CHOICES = 300
    };

public:
    QGCFileDownload(QObject *parent = nullptr);
    ~QGCFileDownload();

    /// Download the specified remote file.
    ///     @param remoteFile File to download. Can be http address or file system path.
    ///     @param requestAttributes Optional request attributes to set
    ///     @param redirect true: call is internal due to redirect
    ///     @return true: Asynchronous download has started, false: Download initialization failed
    bool download(const QString &remoteFile, const QList<QPair<QNetworkRequest::Attribute,QVariant>> &requestAttributes = {}, bool redirect = false);

    void setCache(QAbstractNetworkCache *cache);

    /// Historical OpenSSL mismatch workaround. Kept as a no-op so callers compile,
    /// but certificate errors are never ignored.
    static void setIgnoreSSLErrorsIfNeeded(QNetworkReply &networkReply);

    /// MD5 digest advertised by the origin (Content-MD5 or simple S3 ETag), if any.
    QString serverContentMd5() const;

signals:
    void downloadProgress(qint64 curr, qint64 total);
    void downloadComplete(const QString &remoteFile, const QString &localFile, const QString &errorMsg);

private slots:
    void _downloadFinished();

    /// Called when an error occurs during download
    void _downloadError(QNetworkReply::NetworkError code);

private:
    void _captureServerContentMd5(const QNetworkReply &reply);
    bool _verifyLocalFileMd5(const QString &localFile, const QString &expectedMd5, QString *errorMessage) const;

    QNetworkAccessManager *_networkManager = nullptr;
    QString _originalRemoteFile;
    QString _serverContentMd5;
    QList<QPair<QNetworkRequest::Attribute, QVariant>> _requestAttributes;
};
