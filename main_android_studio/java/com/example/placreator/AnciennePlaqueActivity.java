package com.example.placreator;

import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.pdf.PdfDocument;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputFilter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

public class AnciennePlaqueActivity extends AppCompatActivity {

    private boolean isDocumentOpen = false;

    @Override
    protected void onPause() {
        super.onPause();
        isDocumentOpen = false;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_ancienne_plaque);

        EditText editText = findViewById(R.id.editText);
        editText.setFilters(new InputFilter[]{new InputFilter.AllCaps()});

        Button submitButton = findViewById(R.id.btnAnciennePlaque);
        submitButton.setOnClickListener(v -> {
            String enteredText = editText.getText().toString().trim();
            String formattedText = formatPlaqueNumber(enteredText);
            if (!formattedText.isEmpty()) {
                generateAndOpenPDF(formattedText);
            } else {
                Toast.makeText(this, "Le champ est vide ou invalide", Toast.LENGTH_SHORT).show();
            }
        });
    }

    private String formatPlaqueNumber(String inputText) {
        String cleanedText = inputText.replaceAll("[^A-Za-z0-9]", "").toUpperCase();
        cleanedText = cleanedText.toLowerCase();

        if (cleanedText.length() == 8) {
            return cleanedText.substring(0, 3) + "_" + cleanedText.substring(3, 6) + "_" + cleanedText.substring(6, 8);
        } else if (cleanedText.length() == 9) {
            return cleanedText.substring(0, 4) + "_" + cleanedText.substring(4, 7) + "_" + cleanedText.substring(7, 9);
        } else {
            return "";
        }
    }

    private void generateAndOpenPDF(String content) {
        if (isDocumentOpen) return;

        try {
            // Charger la plaque vierge
            Bitmap plaqueBitmap = loadBitmapFromAssets(this, "plaque_ancien_vierge.jpg");
            if (plaqueBitmap == null) {
                showToast("Impossible de charger la plaque vierge");
                return;
            }

            // Dessiner caractères sur la plaque
            Bitmap finalBitmap = overlayCharactersOnPlaque(plaqueBitmap, content);

            // Création du PDF
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

    private Bitmap loadBitmapFromAssets(Context context, String filename) {
        try (InputStream inputStream = context.getAssets().open(filename)) {
            return BitmapFactory.decodeStream(inputStream);
        } catch (IOException e) {
            return null;
        }
    }

    private Bitmap overlayCharactersOnPlaque(Bitmap plaque, String content) {
        Bitmap result = plaque.copy(Bitmap.Config.ARGB_8888, true);
        Canvas canvas = new Canvas(result);

        int paddingLeft = (content.length() == 10) ? 401 : 282;
        int paddingTop = 65;
        int totalCharacterWidth = 0;
        int characterWidth = 238;
        int characterHeight = 464;

        String chiffresFolder = "lettres_pleine_vignette_ancien/";

        for (int i = 0; i < content.length(); i++) {
            char currentChar = content.charAt(i);
            if (currentChar == '_') {
                totalCharacterWidth += 150; // espacement
                continue;
            }

            try {
                Bitmap charBitmap = loadBitmapFromAssets(this, chiffresFolder + currentChar + ".jpg");
                if (charBitmap != null) {
                    Bitmap scaledChar = Bitmap.createScaledBitmap(charBitmap, characterWidth, characterHeight, true);
                    canvas.drawBitmap(scaledChar, paddingLeft + totalCharacterWidth, paddingTop, null);
                    totalCharacterWidth += characterWidth;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        return result;
    }

    private void showToast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }
}
