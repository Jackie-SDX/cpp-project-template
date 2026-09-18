package com.naylacruz.cppprojecttemplate;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public final class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        TextView view = new TextView(this);
        view.setText(
            "C++ Project Template\n\n" +
            "This APK contains the native projectcli executable for Android."
        );
        view.setTextIsSelectable(true);
        view.setPadding(48, 48, 48, 48);
        setContentView(view);
    }
}
