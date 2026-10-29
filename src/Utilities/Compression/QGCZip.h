#pragma once

#include <QtCore/QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(QGCZipLog)

namespace QGCZip {
    /// Unzip an archive into outputDirectoryPath with ZIP-slip containment.
    /// Used by unit tests; production large-member extracts use extractFile().
    bool unzipFile(const QString &zipFilePath, const QString &outputDirectoryPath);

    /// Extracts one archive member by streaming to disk (safe for large GeoTIFFs /
    /// worker threads). Fallbacks drain unzip stdout while the process runs.
    bool extractFile(const QString &zipFilePath, const QString &memberPath, const QString &outputFilePath);
} // namespace QGCZip
