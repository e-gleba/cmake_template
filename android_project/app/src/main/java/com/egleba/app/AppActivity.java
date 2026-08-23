package com.egleba.app;

import org.libsdl.app.SDLActivity;

public class AppActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[]{
                "02_sdl3_app"
        };
    }
}
