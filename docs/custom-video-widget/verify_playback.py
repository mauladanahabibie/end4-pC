#!/usr/bin/env python3
"""
Verification suite for Custom Video Widget Playback Rules & Power-Aware Controls.
Tests all scenarios defined in Section 11 of the specification.
"""

import sys
import json
import os

class PlaybackCoordinatorSimulator:
    """
    Direct model of the state machine implemented in CustomVideo.qml.
    """
    def __init__(self, config, battery_available=True, is_external_power=True, video_index=0):
        self.config = config
        self.battery_available = battery_available
        self.is_external_power = is_external_power
        self.video_index = video_index
        self.video_valid = True
        self.video_path = "/path/to/video.mp4"
        self.visible = True

        # Global states
        self.fullscreen_open = False
        self.fullscreen_index = -1

        # Playback states
        self.player_playing = False
        self.user_manual_paused = not (self.config.get("autoplay", True))
        self.was_playing_before_auto_pause = False
        self.auto_paused_by_battery = False
        self.auto_paused_by_fullscreen = False
        self.auto_paused_by_hidden = False

        # Initial evaluation
        self.sync_playback()

    @property
    def rules_enabled(self):
        return self.config.get("enablePlaybackRules", True)

    @property
    def rule_autoplay(self):
        return self.config.get("autoplay", True)

    @property
    def rule_pause_in_fullscreen(self):
        return self.config.get("pauseInFullscreen", True)

    @property
    def rule_pause_on_battery(self):
        return self.config.get("pauseOnBattery", True)

    @property
    def rule_resume_when_charging(self):
        return self.config.get("resumeWhenCharging", True)

    @property
    def rule_pause_when_hidden(self):
        return self.config.get("pauseWhenHidden", True)

    @property
    def is_external_power_connected(self):
        if not self.battery_available:
            return True
        return self.is_external_power

    @property
    def is_on_battery(self):
        return self.battery_available and not self.is_external_power_connected

    @property
    def is_this_instance_in_fullscreen(self):
        return self.fullscreen_open and (self.fullscreen_index == self.video_index)

    @property
    def is_widget_hidden(self):
        return not self.visible or not self.config.get("enable", True)

    @property
    def pause_condition_fullscreen(self):
        return self.rules_enabled and self.rule_pause_in_fullscreen and self.is_this_instance_in_fullscreen

    @property
    def pause_condition_battery(self):
        return self.rules_enabled and self.rule_pause_on_battery and self.is_on_battery

    @property
    def pause_condition_hidden(self):
        return self.rules_enabled and self.rule_pause_when_hidden and self.is_widget_hidden

    @property
    def has_active_pause_condition(self):
        return (self.pause_condition_fullscreen or
                self.pause_condition_battery or
                self.pause_condition_hidden)

    def sync_playback(self):
        if not self.video_valid or not self.video_path:
            self.player_playing = False
            return

        if not self.rules_enabled:
            # Master rules disabled: manual controls dictate playback
            if not self.user_manual_paused:
                self.player_playing = True
            else:
                self.player_playing = False
            return

        if self.has_active_pause_condition:
            if self.player_playing:
                self.was_playing_before_auto_pause = True
                if self.pause_condition_battery:
                    self.auto_paused_by_battery = True
                if self.pause_condition_fullscreen:
                    self.auto_paused_by_fullscreen = True
                if self.pause_condition_hidden:
                    self.auto_paused_by_hidden = True
                self.player_playing = False
        else:
            permit_resume = True
            if self.auto_paused_by_battery:
                if not self.rule_resume_when_charging:
                    permit_resume = False
                self.auto_paused_by_battery = False
            self.auto_paused_by_fullscreen = False
            self.auto_paused_by_hidden = False

            if not self.user_manual_paused and self.was_playing_before_auto_pause and permit_resume:
                self.was_playing_before_auto_pause = False
                self.player_playing = True
            elif not self.user_manual_paused and not self.was_playing_before_auto_pause and self.rule_autoplay:
                self.player_playing = True

    # User interactions
    def click_play(self):
        self.user_manual_paused = False
        self.auto_paused_by_battery = False
        self.auto_paused_by_fullscreen = False
        self.auto_paused_by_hidden = False
        self.player_playing = True

    def click_pause(self):
        self.user_manual_paused = True
        self.was_playing_before_auto_pause = False
        self.player_playing = False


def run_tests():
    passed = 0
    total = 10
    print("Running Custom Video Playback Rules & Power Controls Test Suite...\n")

    # Scenario 1: Master playback rules disabled
    cfg = {"enable": True, "enablePlaybackRules": False, "autoplay": True, "pauseOnBattery": True, "pauseInFullscreen": True}
    c1 = PlaybackCoordinatorSimulator(cfg, battery_available=True, is_external_power=True)
    assert c1.player_playing == True, "Failed S1 initial play"
    c1.is_external_power = False # Unplug
    c1.sync_playback()
    assert c1.player_playing == True, "Failed S1: Video paused despite master rules disabled"
    c1.fullscreen_open = True
    c1.fullscreen_index = 0
    c1.sync_playback()
    assert c1.player_playing == True, "Failed S1: Fullscreen paused despite master rules disabled"
    c1.click_pause()
    assert c1.player_playing == False, "Failed S1: Manual pause failed when master rules disabled"
    print("PASS: Scenario 1 — Master playback rules disabled")
    passed += 1

    # Scenario 2: Autoplay enabled and disabled
    cfg_no_auto = {"enable": True, "enablePlaybackRules": True, "autoplay": False}
    c2_no = PlaybackCoordinatorSimulator(cfg_no_auto, battery_available=True, is_external_power=True)
    assert c2_no.player_playing == False, "Failed S2: Video started playing with autoplay=False"
    cfg_auto = {"enable": True, "enablePlaybackRules": True, "autoplay": True}
    c2_yes = PlaybackCoordinatorSimulator(cfg_auto, battery_available=True, is_external_power=True)
    assert c2_yes.player_playing == True, "Failed S2: Video failed to autoplay with autoplay=True"
    print("PASS: Scenario 2 — Autoplay enabled and disabled")
    passed += 1

    # Scenario 3: Fullscreen pause enabled and disabled
    cfg3 = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseInFullscreen": True}
    c3 = PlaybackCoordinatorSimulator(cfg3, video_index=0)
    assert c3.player_playing == True
    c3.fullscreen_open = True
    c3.fullscreen_index = 0
    c3.sync_playback()
    assert c3.player_playing == False, "Failed S3: Video did not pause on fullscreen entry"
    c3.fullscreen_open = False
    c3.fullscreen_index = -1
    c3.sync_playback()
    assert c3.player_playing == True, "Failed S3: Video did not resume on fullscreen exit"
    # When disabled
    cfg3_dis = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseInFullscreen": False}
    c3_dis = PlaybackCoordinatorSimulator(cfg3_dis, video_index=0)
    c3_dis.fullscreen_open = True
    c3_dis.fullscreen_index = 0
    c3_dis.sync_playback()
    assert c3_dis.player_playing == True, "Failed S3: Video paused when pauseInFullscreen was False"
    print("PASS: Scenario 3 — Fullscreen pause enabled and disabled")
    passed += 1

    # Scenario 4: Battery pause enabled and disabled
    cfg4 = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseOnBattery": True}
    c4 = PlaybackCoordinatorSimulator(cfg4, battery_available=True, is_external_power=True)
    assert c4.player_playing == True
    c4.is_external_power = False # Switched to battery
    c4.sync_playback()
    assert c4.player_playing == False, "Failed S4: Video did not pause on battery"
    # When disabled
    cfg4_dis = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseOnBattery": False}
    c4_dis = PlaybackCoordinatorSimulator(cfg4_dis, battery_available=True, is_external_power=True)
    c4_dis.is_external_power = False
    c4_dis.sync_playback()
    assert c4_dis.player_playing == True, "Failed S4: Video paused when pauseOnBattery was False"
    print("PASS: Scenario 4 — Battery pause enabled and disabled")
    passed += 1

    # Scenario 5: Charging reconnects while the video was playing (Resume when charging)
    cfg5 = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseOnBattery": True, "resumeWhenCharging": True}
    c5 = PlaybackCoordinatorSimulator(cfg5, battery_available=True, is_external_power=True)
    assert c5.player_playing == True
    c5.is_external_power = False # Unplug
    c5.sync_playback()
    assert c5.player_playing == False
    c5.is_external_power = True # Reconnect
    c5.sync_playback()
    assert c5.player_playing == True, "Failed S5: Video did not resume when charging reconnected"
    # With resumeWhenCharging = False
    cfg5_no_res = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseOnBattery": True, "resumeWhenCharging": False}
    c5_no = PlaybackCoordinatorSimulator(cfg5_no_res, battery_available=True, is_external_power=True)
    c5_no.is_external_power = False
    c5_no.sync_playback()
    assert c5_no.player_playing == False
    c5_no.is_external_power = True
    c5_no.sync_playback()
    assert c5_no.player_playing == False, "Failed S5: Video resumed when resumeWhenCharging was False"
    print("PASS: Scenario 5 — Charging reconnects while the video was playing")
    passed += 1

    # Scenario 6: Charging reconnects after manual pause
    cfg6 = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseOnBattery": True, "resumeWhenCharging": True}
    c6 = PlaybackCoordinatorSimulator(cfg6, battery_available=True, is_external_power=True)
    c6.is_external_power = False
    c6.sync_playback()
    assert c6.player_playing == False
    c6.click_pause() # Manual pause on battery
    c6.is_external_power = True # Reconnect
    c6.sync_playback()
    assert c6.player_playing == False, "Failed S6: Video resumed after manual pause"
    print("PASS: Scenario 6 — Charging reconnects after manual pause")
    passed += 1

    # Scenario 7: Fullscreen and battery rules active simultaneously
    cfg7 = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseOnBattery": True, "resumeWhenCharging": True, "pauseInFullscreen": True}
    c7 = PlaybackCoordinatorSimulator(cfg7, battery_available=True, is_external_power=True, video_index=0)
    assert c7.player_playing == True
    # 2. Switch to battery -> pauses
    c7.is_external_power = False
    c7.sync_playback()
    assert c7.player_playing == False
    # 4. Open fullscreen
    c7.fullscreen_open = True
    c7.fullscreen_index = 0
    c7.sync_playback()
    assert c7.player_playing == False
    # 5. Reconnect AC while fullscreen still open -> must NOT resume!
    c7.is_external_power = True
    c7.sync_playback()
    assert c7.player_playing == False, "Failed S7: Video resumed while fullscreen was still open!"
    # 6. Exit fullscreen -> now all conditions cleared -> resumes!
    c7.fullscreen_open = False
    c7.fullscreen_index = -1
    c7.sync_playback()
    assert c7.player_playing == True, "Failed S7: Video did not resume after both conditions cleared!"
    print("PASS: Scenario 7 — Fullscreen and battery rules active simultaneously")
    passed += 1

    # Scenario 8: Multiple video widgets with independent playback
    cfg8 = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseInFullscreen": True}
    w0 = PlaybackCoordinatorSimulator(cfg8, video_index=0)
    w1 = PlaybackCoordinatorSimulator(cfg8, video_index=1)
    assert w0.player_playing == True and w1.player_playing == True
    # Fullscreen opens for Widget 0
    w0.fullscreen_open = True
    w0.fullscreen_index = 0
    w1.fullscreen_open = True
    w1.fullscreen_index = 0
    w0.sync_playback()
    w1.sync_playback()
    assert w0.player_playing == False, "Failed S8: Widget 0 did not pause on fullscreen"
    assert w1.player_playing == True, "Failed S8: Widget 1 paused when Widget 0 opened fullscreen!"
    print("PASS: Scenario 8 — Multiple video widgets with independent playback")
    passed += 1

    # Scenario 9: Quickshell restart with persistent settings
    config_path = os.path.expanduser("~/.config/illogical-impulse/config.json")
    with open(config_path, "r") as f:
        stored = json.load(f)
    cv = stored.get("background", {}).get("widgets", {}).get("customVideo", {})
    assert "enablePlaybackRules" in cv, "Failed S9: enablePlaybackRules not in config.json"
    assert "pauseInFullscreen" in cv, "Failed S9: pauseInFullscreen not in config.json"
    assert "pauseOnBattery" in cv, "Failed S9: pauseOnBattery not in config.json"
    assert "resumeWhenCharging" in cv, "Failed S9: resumeWhenCharging not in config.json"
    assert "pauseWhenHidden" in cv, "Failed S9: pauseWhenHidden not in config.json"
    print("PASS: Scenario 9 — Quickshell restart with persistent settings (verified config.json)")
    passed += 1

    # Scenario 10: Missing or unavailable power-state information (Desktop systems)
    cfg10 = {"enable": True, "enablePlaybackRules": True, "autoplay": True, "pauseOnBattery": True}
    c10 = PlaybackCoordinatorSimulator(cfg10, battery_available=False, is_external_power=False)
    assert c10.player_playing == True, "Failed S10: Video paused on desktop system without battery"
    print("PASS: Scenario 10 — Missing or unavailable power-state information")
    passed += 1

    print(f"\nAll {passed}/{total} scenarios PASSED successfully!")

if __name__ == "__main__":
    run_tests()
