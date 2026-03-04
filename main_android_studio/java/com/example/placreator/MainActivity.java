package com.example.placreator;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.ImageButton;

import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.app.AppCompatDelegate;

public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);


        ImageButton btnNouvellePlaque = findViewById(R.id.btnNouvellePlaque);
        ImageButton btnAnciennePlaque = findViewById(R.id.btnAnciennePlaque);

        btnNouvellePlaque.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // Code à exécuter lorsque le bouton "Nouvelle Plaque" est cliqué
                Intent intent = new Intent(MainActivity.this, NouvellePlaqueActivity.class);
                startActivity(intent);
            }
        });

        btnAnciennePlaque.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // Code à exécuter lorsque le bouton "Ancienne Plaque" est cliqué
                Intent intent = new Intent(MainActivity.this, AnciennePlaqueActivity.class);
                startActivity(intent);
            }
        });
    }
}
