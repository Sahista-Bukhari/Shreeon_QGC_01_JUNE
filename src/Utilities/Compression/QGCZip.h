#pragma once

#include <QtCore/QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(QGCZipLog)

namespace QGCZip {
    /// Method to zip files in a given directory
    bool zipDirectory(const QString &directoryPath, const QString &zipFilePath);

    /// Method to unzip files to a given directory
    bool unzipFile(const QString &zipFilePath, const QString &outputDirectoryPath);

    /// Extracts one exact archive member to a file.
    bool extractFile(const QString &zipFilePath, const QString &memberPath, const QString &outputFilePath);
} // namespace QGCZip
