#pragma once

#include <QtCore/QAbstractListModel>
#include <QtCore/QFileSystemWatcher>
#include <QtCore/QTimer>

class RouteMappingImageCatalog : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    explicit RouteMappingImageCatalog(QObject *parent = nullptr);

    static RouteMappingImageCatalog *instance();

    enum Roles {
        FilePathRole = Qt::UserRole + 1,
        FileNameRole,
        FileUrlRole,
        SequenceRole,
    };
    Q_ENUM(Roles)

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void refresh();

signals:
    void countChanged();

private slots:
    void _onCaptureSucceeded(const QString &localPath);
    void _scheduleRefresh();

private:
    void _reloadFromDisk();

    QStringList _imagePaths;
    QFileSystemWatcher _watcher;
    QTimer _refreshDebounce;
};
