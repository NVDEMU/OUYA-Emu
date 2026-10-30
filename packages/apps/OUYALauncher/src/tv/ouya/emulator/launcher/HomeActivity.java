package tv.ouya.emulator.launcher;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/** Minimal OUYA-style home screen and first launcher integration milestone. */
public final class HomeActivity extends Activity {
    private final List<ResolveInfo> games = new ArrayList<>();
    private LinearLayout gameList;
    private TextView status;

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        buildUi();
        refreshGames();
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(48, 28, 48, 24);
        root.setBackgroundColor(Color.rgb(24, 24, 27));

        TextView logo = new TextView(this);
        logo.setText("OUYA");
        logo.setTextColor(Color.rgb(245, 145, 35));
        logo.setTextSize(34);
        logo.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        root.addView(logo);

        TextView subtitle = new TextView(this);
        subtitle.setText("PLAY   DISCOVER   MAKE   MANAGE");
        subtitle.setTextColor(Color.LTGRAY);
        subtitle.setTextSize(14);
        subtitle.setPadding(0, 4, 0, 22);
        root.addView(subtitle);

        status = new TextView(this);
        status.setTextColor(Color.LTGRAY);
        status.setTextSize(16);
        root.addView(status);

        ScrollView scroll = new ScrollView(this);
        gameList = new LinearLayout(this);
        gameList.setOrientation(LinearLayout.VERTICAL);
        scroll.addView(gameList);
        root.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.MATCH_PARENT, 0, 1));

        TextView footer = new TextView(this);
        footer.setText("OUYA-Emu  •  A preservation experiment");
        footer.setTextColor(Color.GRAY);
        footer.setTextSize(12);
        footer.setGravity(Gravity.CENTER_VERTICAL);
        root.addView(footer);
        setContentView(root);
    }

    private void refreshGames() {
        games.clear();
        Intent query = new Intent(Intent.ACTION_MAIN);
        query.addCategory("tv.ouya.intent.category.GAME");
        final PackageManager pm = getPackageManager();
        games.addAll(pm.queryIntentActivities(query, 0));
        Collections.sort(games, new Comparator<ResolveInfo>() {
            @Override
            public int compare(ResolveInfo a, ResolveInfo b) {
                return String.valueOf(a.loadLabel(pm)).compareToIgnoreCase(
                        String.valueOf(b.loadLabel(pm)));
            }
        });

        gameList.removeAllViews();
        status.setText(games.size() + " OUYA game(s) installed");
        if (games.isEmpty()) {
            TextView empty = new TextView(this);
            empty.setText("No OUYA games found. Install an APK declaring "
                    + "tv.ouya.intent.category.GAME.");
            empty.setTextColor(Color.WHITE);
            empty.setTextSize(18);
            empty.setPadding(0, 28, 0, 28);
            gameList.addView(empty);
            return;
        }

        for (final ResolveInfo game : games) {
            TextView item = new TextView(this);
            item.setText(game.loadLabel(pm));
            item.setTextColor(Color.WHITE);
            item.setTextSize(21);
            item.setFocusable(true);
            item.setFocusableInTouchMode(true);
            item.setPadding(20, 18, 20, 18);
            item.setBackgroundColor(Color.rgb(48, 48, 53));
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                    LinearLayout.MATCH_PARENT, LinearLayout.WRAP_CONTENT);
            params.setMargins(0, 5, 0, 5);
            gameList.addView(item, params);
            item.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) { launchGame(game); }
            });
            item.setOnKeyListener(new View.OnKeyListener() {
                @Override
                public boolean onKey(View view, int keyCode, KeyEvent event) {
                    if (event.getAction() == KeyEvent.ACTION_UP
                            && (keyCode == KeyEvent.KEYCODE_BUTTON_A
                            || keyCode == KeyEvent.KEYCODE_ENTER
                            || keyCode == KeyEvent.KEYCODE_DPAD_CENTER)) {
                        launchGame(game);
                        return true;
                    }
                    return false;
                }
            });
        }
        if (gameList.getChildCount() > 0) gameList.getChildAt(0).requestFocus();
    }

    private void launchGame(ResolveInfo game) {
        Intent launch = new Intent(Intent.ACTION_MAIN);
        launch.addCategory("tv.ouya.intent.category.GAME");
        launch.setClassName(game.activityInfo.packageName, game.activityInfo.name);
        try {
            startActivity(launch);
        } catch (RuntimeException error) {
            status.setText("Could not launch game: " + error.getMessage());
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (gameList != null) refreshGames();
    }
}
