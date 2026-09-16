#include "RouteMappingImageCatalog.h"

#include "RouteMappingImageMetadata.h"
#include "RouteMappingPiPhotoCapture.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QUrl>

RouteMappingImageCatalog *RouteMappingImageCatalog::instance()
{
    static RouteMappingImageCatalog s_instance;
    return &s_instance;
}

RouteMappingImageCatalog::RouteMappingImageCatalog(QObject *parent)
    : QAbstractListModel(parent)
{
    _refreshDebounce.setSingleShot(true);
    _refreshDebounce.setInterval(400);
    connect(&_refreshDebounce, &QTimer::timeout, this, &RouteMappingImageCatalog::_reloadFromDisk);

    const QString imageDir = RouteMappingPiPhotoCapture::localSaveDirectory();
    if (QDir(imageDir).exists()) {
        _watcher.addPath(imageDir);
        connect(&_watcher, &QFileSystemWatcher::directoryChanged,
                this, &RouteMappingImageCatalog::_scheduleRefresh);
    }

    connect(RouteMappingPiPhotoCapture::instance(), &RouteMappingPiPhotoCapture::captureSucceeded,
            this, &RouteMappingImageCatalog::_onCaptureSucceeded);

    _reloadFromDisk();
}

int RouteMappingImageCatalog::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return _imagePaths.size();
}

QVariant RouteMappingImageCatalog::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= _imagePaths.size()) {
        return {};
    }

    const QString filePath = _imagePaths.at(index.row());
    const QFileInfo info(filePath);

    switch (role) {
    case FilePathRole:
        return filePath;
    case FileNameRole:
        return info.fileName();
    case FileUrlRole:
        return QUrl::fromLocalFile(filePath).toString();
    case SequenceRole:
        return RouteMappingImageMetadata::sequenceFromImageFileName(filePath);
    default:
        return {};
    }
}

QHash<int, QByteArray> RouteMappingImageCatalog::roleNames() const
{
    return {
        {FilePathRole, "filePath"},
        {FileNameRole, "fileName"},
        {FileUrlRole, "fileUrl"},
        {SequenceRole, "sequence"},
    };
}

void RouteMappingImageCatalog::refresh()
{
    _reloadFromDisk();
}

void RouteMappingImageCatalog::_onCaptureSucceeded(const QString &localPath)
{
    Q_UNUSED(localPath);
    _scheduleRefresh();
}

void RouteMappingImageCatalog::_scheduleRefresh()
{
    _refreshDebounce.start();
}

void RouteMappingImageCatalog::_reloadFromDisk()
{
    const QDir imageDir(RouteMappingPiPhotoCapture::localSaveDirectory());
    if (!imageDir.exists()) {
        return;
    }

    const QFileInfoList entries = imageDir.entryInfoList(
        {QStringLiteral("image_*.jpg")}, QDir::Files, QDir::Name);

    QStringList paths;
    for (const QFileInfo &entry : entries) {
        paths.append(entry.absoluteFilePath());
    }

    if (paths == _imagePaths) {
        return;
    }

    beginResetModel();
    _imagePaths = paths;
    endResetModel();
    emit countChanged();
}
