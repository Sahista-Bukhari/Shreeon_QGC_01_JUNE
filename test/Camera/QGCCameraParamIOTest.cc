#include "QGCCameraParamIOTest.h"
#include "QGCCameraIO.h"
#include "MAVLinkLib.h"

#include <QtTest/QTest>

#include <array>
#include <cstring>

namespace {
constexpr size_t kParamValueLen = MAVLINK_MSG_PARAM_EXT_SET_FIELD_PARAM_VALUE_LEN;

QByteArray patternedBytes(int size)
{
    QByteArray bytes;
    bytes.resize(size);
    for (int i = 0; i < size; ++i) {
        bytes[i] = static_cast<char>(0xA0 + (i % 26));
    }
    return bytes;
}

void verifyCopy(const QByteArray &source, size_t expectedCopied)
{
    std::array<uint8_t, kParamValueLen> dest{};
    const size_t copied = QGCCameraParamIO::copyCustomParamValue(dest.data(), dest.size(), source);

    QCOMPARE(copied, expectedCopied);
    for (size_t i = 0; i < expectedCopied; ++i) {
        QCOMPARE(dest[i], static_cast<uint8_t>(source.at(static_cast<qsizetype>(i))));
    }
    for (size_t i = expectedCopied; i < dest.size(); ++i) {
        QCOMPARE(dest[i], static_cast<uint8_t>(0));
    }
}
} // namespace

void QGCCameraParamIOTest::_testCopyCustomParamValueSizes()
{
    QCOMPARE(kParamValueLen, static_cast<size_t>(128));

    // Size 0: nothing copied; zero-initialized unused bytes preserved
    verifyCopy(QByteArray(), 0);

    // Size 1
    verifyCopy(patternedBytes(1), 1);

    // Size 127 (one below capacity)
    verifyCopy(patternedBytes(127), 127);

    // Size 128 (exact capacity)
    verifyCopy(patternedBytes(128), 128);

    // Size 129 (over capacity): truncate; no overflow of destination
    {
        const QByteArray over = patternedBytes(129);
        verifyCopy(over, 128);

        std::array<uint8_t, kParamValueLen + 8> guard{};
        guard.fill(0x5A);
        // Place destination in the middle of a larger buffer to detect overflow under ASan/manual check
        uint8_t *dest = guard.data() + 4;
        (void) memset(dest, 0, kParamValueLen);

        const size_t copied = QGCCameraParamIO::copyCustomParamValue(dest, kParamValueLen, over);
        QCOMPARE(copied, static_cast<size_t>(128));
        QCOMPARE(dest[127], static_cast<uint8_t>(over.at(127)));
        for (size_t i = 0; i < 4; ++i) {
            QCOMPARE(guard[i], static_cast<uint8_t>(0x5A));
            QCOMPARE(guard[4 + kParamValueLen + i], static_cast<uint8_t>(0x5A));
        }
    }

    // Null destination is a no-op
    QCOMPARE(QGCCameraParamIO::copyCustomParamValue(nullptr, kParamValueLen, QByteArray("x")), static_cast<size_t>(0));
}
