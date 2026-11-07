// SPDX-License-Identifier: GPL-2.0-or-later
#ifndef VLC_REDESIGN_PREFERENCES_HPP
#define VLC_REDESIGN_PREFERENCES_HPP

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QSet>
#include <QTimer>
#include "maininterface/mainctx.hpp"

/** A preferences transaction. Edits stay local until save() succeeds. */
class RedesignPreferences : public QObject
{
    Q_OBJECT
    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(bool autoSave READ autoSave WRITE setAutoSave NOTIFY autoSaveChanged FINAL)
    Q_PROPERTY(bool dirty READ dirty NOTIFY changed FINAL)
    Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY changed FINAL)
public:
    explicit RedesignPreferences(QObject* parent = nullptr);
    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);
    bool autoSave() const { return m_autoSave; }
    void setAutoSave(bool enabled);
    bool dirty() const { return !m_edits.isEmpty() || !m_invalid.isEmpty(); }
    int revision() const { return m_revision; }
    QString errorMessage() const { return m_error; }
    Q_INVOKABLE QVariantList shortcutCatalog() const;
    Q_INVOKABLE QString shortcutForKey(int key, int modifiers) const;
    Q_INVOKABLE QVariantList shortcutConflicts(const QString& name, const QString& shortcut) const;
    Q_INVOKABLE bool assignShortcut(const QString& name, const QString& shortcut, bool replaceConflicts = false);
    Q_INVOKABLE QString choosePath(const QString& name);
    // A folder picked in the dialog of the system, empty if none was
    Q_INVOKABLE QString chooseFolder(const QString& initial);
    // The folder of the system for videos, ~/Videos for instance
    Q_INVOKABLE QString videosFolder() const;
    // Files picked in the dialog of the system, as URLs
    Q_INVOKABLE QStringList chooseFiles();
    Q_INVOKABLE QString chooseColor(const QString& initial);

    // Subtitle files on disk, for the Add Subtitles dialog and the subtitle
    // timeline of the seek bar. Files are given as URLs.
    // The videos of a folder, in the order of their names
    Q_INVOKABLE QStringList videosIn(const QString& folder) const;
    // Subtitle files picked in the dialog of the system, which opens in folder
    Q_INVOKABLE QStringList chooseSubtitleFiles(bool multiple, const QString& folder = QString());
    // Rows of {video, videoName, subtitle, subtitleName, existing}: each
    // video with the subtitle that goes with it, by name, by episode
    // (S01E02, 1x02) or else by order; existing is a file that is already
    // next to the video and that VLC loads by itself.
    Q_INVOKABLE QVariantList pairSubtitles(const QStringList& videos, const QStringList& subtitles) const;
    // Copies each subtitle next to its video under the name of the video,
    // so that VLC loads it with the video; the one of the playing video is
    // also added to it. Returns {saved, failed: [names]}.
    Q_INVOKABLE QVariantMap saveSubtitles(const QVariantList& rows);
    // The times, in ms, of the cues of the subtitle file next to a video
    // (.srt or .vtt of the same name), as [start, end, start, end...]
    Q_INVOKABLE QVariantList subtitleCues(const QString& video) const;

    // Presets for a show: the settings kept for the videos of a folder, the
    // show, and given to each of them when it is opened; see
    // RedesignShowPresets.qml. media is the URL of one of the videos.
    Q_INVOKABLE QString showName(const QString& media) const;
    Q_INVOKABLE QVariantMap showPreset(const QString& media) const;
    Q_INVOKABLE void saveShowPreset(const QString& media, const QVariantMap& preset);
    Q_INVOKABLE void removeShowPreset(const QString& media);
    Q_INVOKABLE QVariantMap describe(const QString& name) const;
    Q_INVOKABLE QVariant value(const QString& name) const;
    Q_INVOKABLE QVariantMap equalizerState() const;
    Q_INVOKABLE QVariantMap equalizerPreset(const QString& name) const;
    Q_INVOKABLE bool stageEqualizerPreset(const QString& name);
    Q_INVOKABLE bool stageEqualizerBand(int index, double gain);
    Q_INVOKABLE bool stageEqualizerPreamp(double gain);
    Q_INVOKABLE bool stage(const QString& name, const QVariant& value);
    Q_INVOKABLE void reset(const QString& name);
    Q_INVOKABLE void discard();
    Q_INVOKABLE bool save();
    Q_INVOKABLE QVariantList catalog(const QString& category, const QString& search = QString()) const;
signals:
    void ctxChanged();
    void autoSaveChanged();
    void changed();
private:
    struct Entry { QString name, category, title; };
    static QVariant read(const QByteArray& name);
    static void write(const QByteArray& name, const QVariant& value);
    MainCtx* m_ctx = nullptr;
    QVariantMap m_edits;
    QSet<QString> m_invalid;
    QList<Entry> m_catalog;
    QString m_error;
    int m_revision = 0;
    bool m_autoSave = false;
    QTimer m_saveTimer;
};
#endif
