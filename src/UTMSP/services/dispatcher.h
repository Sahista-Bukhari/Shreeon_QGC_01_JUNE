#pragma once

#include <chrono>
#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <optional>
#include <thread>

/// Serial worker queue for UTMSP network work.
/// All access to _running is under _queueMutex (no data race).
class Dispatcher
{
public:
    /// Minimum delay after a task finishes before the next task may start.
    static constexpr std::chrono::milliseconds kMinTaskInterval{1000};

    Dispatcher()
        : _running(true)
    {
        _workerThread = std::thread([this]() { workerLoop(); });
    }

    Dispatcher(const Dispatcher &) = delete;
    Dispatcher &operator=(const Dispatcher &) = delete;

    ~Dispatcher()
    {
        {
            std::lock_guard<std::mutex> lock(_queueMutex);
            _running = false;
        }
        _conditionVariable.notify_all();
        if (_workerThread.joinable()) {
            _workerThread.join();
        }
    }

    void add_task(std::function<void()> task)
    {
        {
            std::lock_guard<std::mutex> lock(_queueMutex);
            if (!_running) {
                return;
            }
            _tasks.push_back(std::move(task));
        }
        _conditionVariable.notify_one();
    }

private:
    void workerLoop()
    {
        using clock = std::chrono::steady_clock;
        std::optional<clock::time_point> nextTaskAllowed;

        while (true) {
            std::function<void()> task;
            {
                std::unique_lock<std::mutex> lock(_queueMutex);

                // Rate limiter: wait out the interval, but wake immediately on stop
                // so ~Dispatcher() is not blocked by an unconditional sleep.
                if (nextTaskAllowed.has_value()) {
                    _conditionVariable.wait_until(lock, *nextTaskAllowed, [this] {
                        return !_running;
                    });
                }

                _conditionVariable.wait(lock, [this] {
                    return !_tasks.empty() || !_running;
                });
                if (!_running && _tasks.empty()) {
                    return;
                }
                if (_tasks.empty()) {
                    continue;
                }
                task = std::move(_tasks.front());
                _tasks.pop_front();
            }

            task();
            nextTaskAllowed = clock::now() + kMinTaskInterval;
        }
    }

    std::deque<std::function<void()>> _tasks;
    std::mutex _queueMutex;
    std::condition_variable _conditionVariable;
    std::thread _workerThread;
    bool _running; ///< Guarded by _queueMutex
};
