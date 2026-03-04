package com.example.placreator;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputFilter;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.FileProvider;


import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.pdf.PdfDocument;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;



public class NouvellePlaqueActivity extends AppCompatActivity {
    private boolean isDocumentOpen = false;

    @Override
    protected void onPause() {
        super.onPause();
        isDocumentOpen = false;
    }
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_nouvelle_plaque);
        EditText editText1 = findViewById(R.id.editText1);
        editText1.setFilters(new InputFilter[] { new InputFilter.AllCaps() });

        Button submitButton = findViewById(R.id.btnAnciennePlaque);
        submitButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String enteredText = editText1.getText().toString().trim();
                String formattedText = formatPlaqueNumber(enteredText);

                // Get the text from EditText2
                EditText editText2 = findViewById(R.id.editText2);
                String additionalText = editText2.getText().toString().trim();

                if (!formattedText.isEmpty() && !additionalText.isEmpty()) {
                     generateAndOpenPDF(formattedText, additionalText);
                } else {
                    showToast("Un champ est vide");
                }
            }
        });
    }

    private String formatPlaqueNumber(String inputText) {
        // Remove all non-alphanumeric characters and convert to uppercase
        String cleanedText = inputText.replaceAll("[^A-Za-z0-9]", "").toUpperCase();
        cleanedText = cleanedText.toLowerCase();

        // Check if the input is of the correct length (6 or 7 characters)
        if (cleanedText.length() == 7) {
            // Apply the format "12-345-67"
            return cleanedText.substring(0, 2) + "-" + cleanedText.substring(2, 5) + "-" + cleanedText.substring(5,7);
        } else {
            // Return an empty string if the input is not of the correct length
            return "";
        }
    }

    private void generateAndOpenPDF(String content1, String content2) {
        if (isDocumentOpen) return;

        try {
            // Générer le bitmap complet de la plaque (caractères + département + logo)
            Bitmap finalBitmap = generatePlaqueBitmap(content1, content2);
            if (finalBitmap == null) {
                showToast("Impossible de générer la plaque");
                return;
            }

            // Créer un fichier PDF dans le répertoire interne
            File pdfFile = new File(getFilesDir(), "plaque.pdf");
            PdfDocument document = new PdfDocument();
            PdfDocument.PageInfo pageInfo = new PdfDocument.PageInfo.Builder(595, 842, 1).create(); // A4

            // ⚡ Mise à l’échelle selon ton calcul
            float scale = (float) pageInfo.getPageHeight() / finalBitmap.getWidth() * 520f/297f;
            float newWidth = finalBitmap.getWidth() * scale;
            float newHeight = finalBitmap.getHeight() * scale;

            // Matrice de base : scale + centrage + rotation
            Matrix baseMatrix = new Matrix();
            baseMatrix.postScale(scale, scale);

            // Centrage horizontal et vertical
            float x = (pageInfo.getPageWidth() - newWidth) / 2f;
            float y = (pageInfo.getPageHeight() - newHeight) / 2f;
            baseMatrix.postTranslate(x, y);

            // Rotation autour du centre de la page
            baseMatrix.postRotate(90f, pageInfo.getPageWidth() / 2f, pageInfo.getPageHeight() / 2f);

            // ⚡ Crée deux matrices pour découper l’image en deux pages
            Matrix topMatrix = new Matrix(baseMatrix);
            Matrix bottomMatrix = new Matrix(baseMatrix);

            // Décalage vertical pour la deuxième moitié
            topMatrix.postTranslate(0, newWidth * 112f/ 520f);
            bottomMatrix.postTranslate(0, -newWidth * 112f/ 520f);

            // --- Page 1 ---
            PdfDocument.Page page1 = document.startPage(pageInfo);
            page1.getCanvas().drawBitmap(finalBitmap, topMatrix, null);
            document.finishPage(page1);

            // --- Page 2 ---
            PdfDocument.Page page2 = document.startPage(pageInfo);
            page2.getCanvas().drawBitmap(finalBitmap, bottomMatrix, null);
            document.finishPage(page2);

            // Sauvegarde du PDF
            FileOutputStream fos = new FileOutputStream(pdfFile);
            document.writeTo(fos);
            document.close();
            fos.close();

            // Ouvrir le PDF avec une app externe
            Uri pdfUri = FileProvider.getUriForFile(this, "com.example.placreator.fileprovider", pdfFile);
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(pdfUri, "application/pdf");
            intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

            if (intent.resolveActivity(getPackageManager()) != null) {
                startActivity(intent);
            }

            isDocumentOpen = true;

        } catch (Exception e) {
            e.printStackTrace();
            showToast("Erreur lors de la génération du PDF");
        }
    }

    private Bitmap generatePlaqueBitmap(String content1, String content2) throws IOException {
        // Charger l'image de base (plaque vierge) depuis assets
        String imageName = "plaque_vierge.jpg";
        Context context = NouvellePlaqueActivity.this;
        InputStream inputStream = context.getAssets().open(imageName);
        Bitmap baseBitmap = BitmapFactory.decodeStream(inputStream).copy(Bitmap.Config.ARGB_8888, true);

        // Créer un Canvas pour dessiner dessus
        Canvas canvas = new Canvas(baseBitmap);

        // ======================
        // Caractères principaux
        // ======================
        String chiffresFolder = "lettres_pleines_vignette/";
        int paddingLeft = 383;
        int paddingTop = 65;
        int characterWidth = 238; // largeur fixe prévue
        int totalCharacterWidth = 0;

        for (int i = 0; i < content1.length(); i++) {
            char currentChar = content1.charAt(i);
            String imageChiffreName = currentChar + ".jpg";
            InputStream inputStreamChiffre = context.getAssets().open(chiffresFolder + imageChiffreName);
            Bitmap bitmapChiffre = BitmapFactory.decodeStream(inputStreamChiffre);

            // Position où dessiner
            int destX = paddingLeft + totalCharacterWidth;
            int destY = paddingTop;
            canvas.drawBitmap(bitmapChiffre, destX, destY, null);

            totalCharacterWidth += characterWidth;
            inputStreamChiffre.close();
        }

        // ======================
        // Département (2 chiffres)
        // ======================
        chiffresFolder = "lettres_departement/";
        paddingLeft = 2660;
        paddingTop = 340;
        characterWidth = 124;
        totalCharacterWidth = 0;

        for (int i = 0; i < content2.length(); i++) {
            char currentChar = content2.charAt(i);
            String imageChiffreName = currentChar + ".jpg";
            InputStream inputStreamChiffre = context.getAssets().open(chiffresFolder + imageChiffreName);
            Bitmap bitmapChiffre = BitmapFactory.decodeStream(inputStreamChiffre);

            int destX = paddingLeft + totalCharacterWidth;
            int destY = paddingTop;
            canvas.drawBitmap(bitmapChiffre, destX, destY, null);

            totalCharacterWidth += characterWidth;
            inputStreamChiffre.close();
        }

        // ======================
        // Logo région
        // ======================
        String logoFolder = "logo_taille/";
        String region = Constantes.REGION.get(content2);
        String logoName = region + ".jpg";
        InputStream inputStreamLogo = context.getAssets().open(logoFolder + logoName);
        Bitmap bitmapLogo = BitmapFactory.decodeStream(inputStreamLogo);

        paddingLeft = 2672;
        paddingTop = 55 - (bitmapLogo.getHeight() - 220) / 2;

        canvas.drawBitmap(bitmapLogo, paddingLeft, paddingTop, null);
        inputStreamLogo.close();

        // Retourne la plaque finale (toujours un Bitmap, comme ton premier exemple)
        return baseBitmap;
    }

    private void showToast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }
}
