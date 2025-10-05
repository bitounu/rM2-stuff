#pragma once

#include <Input.h>
#include <UI/RenderObject.h>
#include <UI/Timer.h>

#include <vector>

namespace rmlib {

class AppContext {
public:
  static ErrorOr<AppContext> makeContext(std::optional<Size> size = {}) {
    auto fb = TRY(fb::FrameBuffer::open(size));
    auto ctx = AppContext(std::move(fb));
    TRY(ctx.inputManager.openAll());
    return ctx;
  }

  TimerHandle addTimer(
    std::chrono::microseconds duration,
    Callback trigger,
    std::optional<std::chrono::microseconds> repeat = std::nullopt) {
    auto [timer, handle] =
      Timer::makeTimer(duration, std::move(trigger), repeat);
    timers.emplace(std::move(timer));
    return std::move(handle);
  }

  std::optional<std::chrono::microseconds> getNextDuration() const {
    if (timers.empty()) {
      return std::nullopt;
    }

    auto duration = timers.top()->getDuration();
    if (duration < std::chrono::microseconds(0)) {
      return std::chrono::microseconds(0);
    }
    return duration;
  }

  void checkTimers() {
    while (!timers.empty()) {
      std::shared_ptr<Timer> top = timers.top();
      if (top->check()) {
        timers.pop();

        if (top->repeats()) {
          top->reset();
          timers.emplace(std::move(top));
        }
      } else {
        break;
      }
    }
  }

  void stop() { mShouldStop = true; }

  bool shouldStop() const { return mShouldStop; }

  void doLater(Callback fn) { doLaters.emplace_back(std::move(fn)); }
  void doAllLaters() {
    for (const auto& doLater : doLaters) {
      doLater();
    }
    doLaters.clear();
  }

  input::InputManager& getInputManager() { return inputManager; }

  const Canvas& getFbCanvas() const { return framebuffer.canvas; }
  const fb::FrameBuffer& getFramebuffer() const { return framebuffer; }
  fb::FrameBuffer& getFramebuffer() { return framebuffer; }

  void onDeviceUpdate(Callback fn) {
    onDeviceUpdates.emplace_back(std::move(fn));
  }

  void listenFd(int fd, Callback callback) {
    extraFds.emplace(fd, std::move(callback));
  }

  ErrorOr<std::vector<input::Event>> waitForInput(
    std::optional<std::chrono::microseconds> durantion) {

    const auto milliDuration =
      [durantion]() -> std::optional<std::chrono::milliseconds> {
      if (!durantion.has_value()) {
        return {};
      }
      return std::chrono::duration_cast<std::chrono::milliseconds>(*durantion);
    }();

    std::size_t startDevices = inputManager.numDevices();
    std::vector<input::Event> result;

    if (!extraFds.empty()) {
      std::vector<pollfd> pollFds;
      for (const auto& [fd, _] : extraFds) {
        pollFds.emplace_back(
          pollfd{ .fd = fd, .events = POLLIN, .revents = 0 });
      }

      auto evs = TRY(inputManager.waitForInput(pollFds, milliDuration));

      for (const auto& poll : pollFds) {
        if (unistdpp::canRead(poll)) {
          extraFds[poll.fd]();
        }
      }

      result = std::move(evs);
    } else {
      auto evs = TRY(inputManager.waitForInput(milliDuration));
      result = std::move(evs);
    }

    if (inputManager.numDevices() != startDevices) {
      for (const auto& onDeviceUpdate : onDeviceUpdates) {
        onDeviceUpdate();
      }
    }

    return result;
  }

  void setRootRenderObject(std::unique_ptr<RenderObject> obj) {
    rootRO = std::move(obj);
  }

  RenderObject& getRootRenderObject() { return *rootRO; }

  void step() {
    rootRO->rebuild(*this, nullptr);

    const auto size = rootRO->layout(rootConstraints);
    const auto rect = rmlib::Rect{ { 0, 0 }, size.toPoint() };

    auto updateRegion = rootRO->cleanup(framebuffer.canvas);
    updateRegion |= rootRO->draw(rect, framebuffer.canvas);

    if (!updateRegion.region.empty()) {
      framebuffer.doUpdate(
        updateRegion.region, updateRegion.waveform, updateRegion.flags);
    }

    const auto duration = getNextDuration();
    const auto evsOrError = waitForInput(duration);
    checkTimers();
    doAllLaters();

    if (!evsOrError.has_value()) {
      std::cerr << evsOrError.error().msg << std::endl;
    } else {
      for (const auto& ev : *evsOrError) {
        rootRO->handleInput(ev);
      }
    }

    rootRO->reset();
  }

protected:
  AppContext(fb::FrameBuffer fb) : framebuffer(std::move(fb)) {
    const auto fbSize =
      Size{ framebuffer.canvas.width(), framebuffer.canvas.height() };
    rootConstraints = Constraints{ fbSize, fbSize };
  }

  fb::FrameBuffer framebuffer; // NOLINT (not private)

private:
  input::InputManager inputManager;

  TimerQueue timers;
  // TODO: use handles to destroy these
  std::vector<Callback> doLaters;
  std::vector<Callback> onDeviceUpdates;

  std::unordered_map<int, Callback> extraFds;

  bool mShouldStop = false;

  std::unique_ptr<RenderObject> rootRO;
  Constraints rootConstraints{};
};

} // namespace rmlib
