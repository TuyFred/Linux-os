/* Group 2 OS — live date/time on the GDM / unlock screen (system time zone). */
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class Group2LoginClockExtension extends Extension {
    enable() {
        this._box = new St.BoxLayout({
            style_class: 'group2-login-clock-box',
            vertical: true,
            x_expand: true,
            y_expand: false,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.END,
        });
        this._time = new St.Label({
            style_class: 'group2-login-clock-time',
            text: '',
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._date = new St.Label({
            style_class: 'group2-login-clock-date',
            text: '',
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._zone = new St.Label({
            style_class: 'group2-login-clock-zone',
            text: '',
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._box.add_child(this._time);
        this._box.add_child(this._date);
        this._box.add_child(this._zone);

        Main.layoutManager.uiGroup.add_child(this._box);
        this._monId = Main.layoutManager.connect('monitors-changed', () => this._place());
        this._place();
        this._tick();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this._tick();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _place() {
        if (!this._box)
            return;
        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor)
            return;
        const w = Math.min(520, monitor.width - 40);
        const h = 120;
        this._box.set_size(w, h);
        this._box.set_position(
            monitor.x + Math.floor((monitor.width - w) / 2),
            monitor.y + monitor.height - h - 40
        );
    }

    _tick() {
        const now = GLib.DateTime.new_now_local();
        if (!now)
            return;
        this._time.text = now.format('%H:%M:%S');
        this._date.text = now.format('%A, %d %B %Y');
        let zoneId = 'local time';
        try {
            const tz = GLib.TimeZone.new_local();
            if (tz && tz.get_identifier)
                zoneId = tz.get_identifier();
        } catch (e) {
            /* ignore */
        }
        const abbr = now.get_timezone_abbreviation() || '';
        this._zone.text = abbr ? `${zoneId}  ·  ${abbr}` : zoneId;
        this._place();
    }

    disable() {
        if (this._timer) {
            GLib.source_remove(this._timer);
            this._timer = 0;
        }
        if (this._monId) {
            Main.layoutManager.disconnect(this._monId);
            this._monId = 0;
        }
        if (this._box) {
            this._box.destroy();
            this._box = null;
        }
        this._time = null;
        this._date = null;
        this._zone = null;
    }
}
