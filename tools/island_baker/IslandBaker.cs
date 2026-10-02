// Horneador de la isla de la Beta.
// Diseña la isla (inspirada en la imagen de referencia) y genera 4 mapas de 1024x1024:
//   height.png  -> altura del terreno en voxels, 16 bits (R = byte alto, G = byte bajo, valor = altura * 64)
//   water.png   -> nivel de la superficie del agua de ríos/lagos, misma codificación (0 = sin agua)
//   biome.png   -> bioma por color de paleta (se puede repintar a mano con estos mismos colores)
//   preview.png -> vista cenital con sombreado, solo para comparar con la referencia
// Coordenadas: u de oeste (0) a este (1), v de norte (0) a sur (1).
// Compatible con C# 5 (lo compila Windows PowerShell 5.1).

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class IslandBaker
{
    public const int N = 1024;
    public const float SEA = 24f;     // nivel del mar en voxels
    public const float SNOW = 175f;   // línea de nieve (solo cimas y aristas)
    public const float VOXELS_PER_PX = 2f;

    // IDs de bioma (deben coincidir con island_generator.gd).
    public const byte OCEAN = 0, BEACH = 1, MEADOW = 2, FOREST = 3, PINE = 4, ALPINE = 5,
                      CORRUPT = 6, VILLAGE = 7, FARM = 8, WATER = 9;

    // IDs de bloque (deben coincidir con island_generator.gd y la librería de main.gd).
    const byte BL_GRASS = 1, BL_DIRT = 2, BL_STONE = 3, BL_SAND = 4, BL_SNOW = 5, BL_CORRUPT_SOIL = 10, BL_WHEAT = 12;
    // Tipos de árbol.
    const int TREE_BROAD = 1, TREE_PINE = 2, TREE_DEAD = 3;
    const float TREE_LINE = 150f;
    const float STEEP = 1.1f;  // pendiente (voxels de subida por voxel) a partir de la cual es pared

    public static readonly int[][] PALETTE = new int[][] {
        new int[] { 20, 60, 140 },   // OCEAN
        new int[] { 230, 210, 150 }, // BEACH
        new int[] { 140, 200, 90 },  // MEADOW
        new int[] { 40, 120, 50 },   // FOREST
        new int[] { 30, 80, 60 },    // PINE
        new int[] { 150, 150, 150 }, // ALPINE
        new int[] { 90, 50, 110 },   // CORRUPT
        new int[] { 200, 160, 110 }, // VILLAGE
        new int[] { 230, 200, 60 },  // FARM
        new int[] { 60, 170, 220 },  // WATER
    };

    // Zoom del diseño: <1 hace que la isla ocupe más parte del mapa.
    const float ZOOM = 0.86f;
    static float ToDesign(float t) { return 0.5f + (t - 0.5f) * ZOOM; }
    static float FromDesign(float t) { return 0.5f + (t - 0.5f) / ZOOM; }

    // Lago en la meseta de la montaña (coordenadas de diseño).
    const float LAKE_U = 0.705f, LAKE_V = 0.392f, LAKE_R = 0.030f;

    // Recorrido del río: del lago a la costa sur (puntos de control, se suaviza con Catmull-Rom).
    static readonly float[][] RIVER = new float[][] {
        new float[] { 0.705f, 0.392f }, new float[] { 0.680f, 0.410f }, new float[] { 0.650f, 0.432f },
        new float[] { 0.620f, 0.462f }, new float[] { 0.588f, 0.508f }, new float[] { 0.562f, 0.548f },
        new float[] { 0.576f, 0.592f }, new float[] { 0.552f, 0.636f }, new float[] { 0.532f, 0.676f },
        new float[] { 0.556f, 0.716f }, new float[] { 0.600f, 0.752f }, new float[] { 0.634f, 0.792f },
        new float[] { 0.650f, 0.842f }, new float[] { 0.664f, 0.892f }, new float[] { 0.674f, 0.942f },
        new float[] { 0.680f, 0.995f },
    };

    static int[] perm;

    // ---------------------------------------------------------------- utilidades

    static float Lerp(float a, float b, float t) { return a + (b - a) * t; }
    static float Clamp01(float x) { return x < 0f ? 0f : (x > 1f ? 1f : x); }
    static float Smooth(float t) { t = Clamp01(t); return t * t * (3f - 2f * t); }
    static float Pow(float x, float p) { return (float)Math.Pow(Math.Max(x, 0f), p); }
    static float Len(float x, float y) { return (float)Math.Sqrt(x * x + y * y); }

    // Mancha suave elíptica: 1 en el centro, 0 en el borde.
    static float Blob(float u, float v, float cx, float cy, float rx, float ry)
    {
        float dx = (u - cx) / rx, dy = (v - cy) / ry;
        float d = dx * dx + dy * dy;
        if (d >= 1f) return 0f;
        return Smooth(1f - d);
    }

    static void InitNoise(int seed)
    {
        Random r = new Random(seed);
        int[] p = new int[256];
        for (int i = 0; i < 256; i++) p[i] = i;
        for (int i = 255; i > 0; i--) { int j = r.Next(i + 1); int t = p[i]; p[i] = p[j]; p[j] = t; }
        perm = new int[512];
        for (int i = 0; i < 512; i++) perm[i] = p[i & 255];
    }

    static float Fade(float t) { return t * t * t * (t * (t * 6f - 15f) + 10f); }

    static float Grad(int h, float x, float y)
    {
        switch (h & 7)
        {
            case 0: return x + y;
            case 1: return -x + y;
            case 2: return x - y;
            case 3: return -x - y;
            case 4: return x;
            case 5: return -x;
            case 6: return y;
            default: return -y;
        }
    }

    // Ruido de Perlin 2D, aprox. en [-1, 1].
    static float Perlin(float x, float y)
    {
        int xi = (int)Math.Floor(x), yi = (int)Math.Floor(y);
        float xf = x - xi, yf = y - yi;
        int X = xi & 255, Y = yi & 255;
        float fu = Fade(xf), fv = Fade(yf);
        int aa = perm[perm[X] + Y], ab = perm[perm[X] + Y + 1];
        int ba = perm[perm[X + 1] + Y], bb = perm[perm[X + 1] + Y + 1];
        float x1 = Lerp(Grad(aa, xf, yf), Grad(ba, xf - 1f, yf), fu);
        float x2 = Lerp(Grad(ab, xf, yf - 1f), Grad(bb, xf - 1f, yf - 1f), fu);
        return Lerp(x1, x2, fv) * 0.7f;
    }

    static float Fbm(float x, float y, int octaves)
    {
        float sum = 0f, amp = 1f, total = 0f, f = 1f;
        for (int i = 0; i < octaves; i++)
        {
            sum += Perlin(x * f, y * f) * amp;
            total += amp; amp *= 0.5f; f *= 2f;
        }
        return sum / total;
    }

    // Ruido de crestas, en [0, 1].
    static float Ridged(float x, float y, int octaves)
    {
        float sum = 0f, amp = 1f, total = 0f, f = 1f;
        for (int i = 0; i < octaves; i++)
        {
            float n = 1f - Math.Abs(Perlin(x * f, y * f));
            sum += n * n * amp;
            total += amp; amp *= 0.5f; f *= 2f;
        }
        return sum / total;
    }

    static float SampleBilinear(float[] a, float px, float py)
    {
        if (px < 0f) px = 0f; if (py < 0f) py = 0f;
        if (px > N - 1) px = N - 1; if (py > N - 1) py = N - 1;
        int x0 = (int)px, y0 = (int)py;
        int x1 = Math.Min(x0 + 1, N - 1), y1 = Math.Min(y0 + 1, N - 1);
        float tx = px - x0, ty = py - y0;
        float a0 = Lerp(a[y0 * N + x0], a[y0 * N + x1], tx);
        float a1 = Lerp(a[y1 * N + x0], a[y1 * N + x1], tx);
        return Lerp(a0, a1, ty);
    }

    // ---------------------------------------------------------------- horneado

    public static string Bake(string outDir, int seed)
    {
        InitNoise(seed);
        int count = N * N;
        float[] H = new float[count];
        float[] W = new float[count];
        float[] C = new float[count];
        float[] mountain = new float[count];
        float[] corrupt = new float[count];
        float[] village = new float[count];
        float[] farm = new float[count];
        float[] castle = new float[count];
        byte[] B = new byte[count];

        // Pináculos rocosos de la zona corrupta.
        Random rnd = new Random(seed + 7);
        List<float[]> pins = new List<float[]>();
        for (int i = 0; i < 30; i++)
        {
            float a = (float)(rnd.NextDouble() * Math.PI * 2.0);
            float r = (float)Math.Sqrt(rnd.NextDouble());
            float cx = 0.66f + (float)Math.Cos(a) * r * 0.24f;
            float cy = 0.19f + (float)Math.Sin(a) * r * 0.09f;
            float rad = 0.005f + (float)rnd.NextDouble() * 0.008f;
            float hgt = 16f + (float)rnd.NextDouble() * 38f;
            pins.Add(new float[] { cx, cy, rad, hgt });
        }

        // --- 1. Terreno base: costa, colinas, montaña, zona corrupta, ruinas, pueblo, campos.
        for (int y = 0; y < N; y++)
        {
            for (int x = 0; x < N; x++)
            {
                int i = y * N + x;
                float u = ToDesign(x / (float)(N - 1)), v = ToDesign(y / (float)(N - 1));

                // Deformación del dominio para que la costa no tenga formas geométricas.
                float wu = u + 0.06f * Fbm(u * 3.5f, v * 3.5f, 4) + 0.02f * Fbm(u * 11f + 7f, v * 11f, 3);
                float wv = v + 0.06f * Fbm(u * 3.5f + 5.2f, v * 3.5f + 1.3f, 4) + 0.02f * Fbm(u * 11f, v * 11f + 3f, 3);

                float F = 0f;
                F += Blob(wu, wv, 0.50f, 0.58f, 0.40f, 0.33f);  // cuerpo principal
                F += Blob(wu, wv, 0.30f, 0.42f, 0.22f, 0.22f);  // oeste-centro
                F += Blob(wu, wv, 0.74f, 0.48f, 0.23f, 0.28f);  // macizo del este
                F += Blob(wu, wv, 0.63f, 0.22f, 0.30f, 0.15f);  // norte (zona corrupta)
                F += Blob(wu, wv, 0.27f, 0.22f, 0.14f, 0.10f);  // colina de las ruinas
                F += Blob(wu, wv, 0.42f, 0.80f, 0.27f, 0.14f);  // sur
                F += Blob(wu, wv, 0.15f, 0.68f, 0.11f, 0.17f);  // lóbulo oeste
                F += Blob(wu, wv, 0.13f, 0.86f, 0.06f, 0.06f);  // cabo suroeste
                // Islotes.
                F += 0.9f * Blob(wu, wv, 0.07f, 0.30f, 0.025f, 0.022f);
                F += 0.9f * Blob(wu, wv, 0.04f, 0.56f, 0.020f, 0.020f);
                F += 0.9f * Blob(wu, wv, 0.46f, 0.975f, 0.025f, 0.018f);
                F += 0.9f * Blob(wu, wv, 0.33f, 0.96f, 0.018f, 0.015f);
                F += 0.9f * Blob(wu, wv, 0.94f, 0.80f, 0.020f, 0.020f);
                F = Math.Min(F, 1.3f);
                // Bahías y calas.
                F -= 1.3f * Blob(wu, wv, 0.24f, 0.83f, 0.075f, 0.065f);  // bahía del puerto
                F -= 1.3f * Blob(wu, wv, 0.21f, 0.93f, 0.050f, 0.060f);  // boca de la bahía
                F -= 1.0f * Blob(wu, wv, 0.05f, 0.45f, 0.050f, 0.070f);
                F -= 1.0f * Blob(wu, wv, 0.96f, 0.62f, 0.050f, 0.080f);
                F -= 1.0f * Blob(wu, wv, 0.44f, 0.10f, 0.070f, 0.060f);
                F -= 0.8f * Blob(wu, wv, 0.58f, 0.97f, 0.050f, 0.040f);
                F += 0.30f * Fbm(u * 16f, v * 16f, 4);  // costa rota: calas y salientes

                float c = F - 0.5f;  // > 0 tierra, < 0 mar
                C[i] = c;

                float h;
                if (c < 0f)
                {
                    h = SEA - 1f + c * 45f;  // plataforma de aguas someras (turquesa) y luego fondo
                    if (h < 4f) h = 4f;
                }
                else
                {
                    // La altura sube cerca de la costa y luego la dan las colinas (sin "círculos").
                    // Las colinas empiezan algo tierra adentro: deja una franja llana para playas.
                    float land = Smooth((c - 0.03f) / 0.10f);
                    h = SEA + 0.8f + Smooth(c / 0.22f) * 14f;
                    float hills = Fbm(u * 6f, v * 6f, 5) * 0.5f + 0.5f;
                    h += hills * hills * 30f * land;
                    h += Ridged(u * 12f + 1.7f, v * 12f + 4.1f, 3) * 12f * land;  // lomas onduladas
                    h += Fbm(u * 30f, v * 30f, 2) * 2f * land;
                }

                // Macizo del este: pico principal + secundario, crestas y faldas largas.
                float mp = Smooth(1f - Len((u - 0.75f) / 0.20f, (v - 0.47f) / 0.24f));
                float mp2 = Smooth(1f - Len((u - 0.69f) / 0.09f, (v - 0.55f) / 0.09f));
                if (c > -0.05f)
                {
                    // Menos cúpula y más crestas: nieve en las aristas, roca en los valles.
                    float ridge = Ridged(u * 7f, v * 7f, 5);
                    h += Pow(mp, 1.8f) * 125f + ridge * 70f * Pow(mp, 1.4f) + mp2 * 30f;
                }
                // Borde irregular del pinar de montaña.
                mountain[i] = Math.Max(mp, mp2 * 0.8f) + 0.4f * Fbm(u * 10f + 2f, v * 10f + 9f, 3);

                // Zona corrupta del norte: tierras altas con pináculos y la meseta de la torre.
                float cm = Smooth((1f - Len((u - 0.65f) / 0.28f, (v - 0.20f) / 0.12f)) * 1.6f
                                  + 1.1f * Fbm(u * 8f + 3f, v * 8f + 7f, 4));
                corrupt[i] = cm;
                if (c > 0f) h += cm * 16f + Ridged(u * 14f, v * 14f, 3) * 10f * cm;
                for (int k = 0; k < pins.Count; k++)
                {
                    float[] p = pins[k];
                    float d = Len(u - p[0], v - p[1]) / p[2];
                    if (d < 1f) h += p[3] * Pow(1f - d, 0.75f) * (c > 0f ? 1f : 0.6f);  // agujas afiladas
                }
                float td = Len(u - 0.70f, v - 0.15f) / 0.022f;
                if (td < 1f) h += 40f * Smooth((1f - td) * 2.5f);

                // Colina de las ruinas (noroeste): meseta de laderas empinadas.
                float kp = Smooth((1f - Len((u - 0.27f) / 0.065f, (v - 0.21f) / 0.055f)) * 1.8f);
                castle[i] = kp;
                if (c > 0f) h = Math.Max(h, Lerp(h, SEA + 30f, kp));

                // Llano del pueblo junto a la bahía y campos de cultivo.
                float edge = 0.9f * Fbm(u * 18f + 4f, v * 18f + 1f, 3);
                float vp = Smooth((1f - Len((u - 0.265f) / 0.075f, (v - 0.755f) / 0.055f)) * 2f + edge);
                village[i] = vp;
                if (c > 0f) h = Lerp(h, SEA + 3f, vp);
                float fp = Smooth((1f - Len((u - 0.37f) / 0.060f, (v - 0.65f) / 0.045f)) * 2f + edge);
                farm[i] = fp;
                if (c > 0f) h = Lerp(h, SEA + 6f + Fbm(u * 20f, v * 20f, 2), fp);

                H[i] = h;
            }
        }

        // --- 1b. Playas: franjas de arena de anchura variable junto al mar.
        bool[] beach = CarveBeaches(H, mountain, corrupt, castle, village);

        // --- 2. Lago en una meseta de la montaña.
        int lcx = (int)(FromDesign(LAKE_U) * (N - 1)), lcy = (int)(FromDesign(LAKE_V) * (N - 1));
        float lakeLevel = 0f; int lakeSamples = 0;
        for (int dy = -3; dy <= 3; dy++)
            for (int dx = -3; dx <= 3; dx++) { lakeLevel += H[(lcy + dy) * N + lcx + dx]; lakeSamples++; }
        lakeLevel = (float)Math.Round(lakeLevel / lakeSamples);

        int lakeBox = (int)(0.08f * N);
        for (int y = Math.Max(0, lcy - lakeBox); y < Math.Min(N, lcy + lakeBox); y++)
        {
            for (int x = Math.Max(0, lcx - lakeBox); x < Math.Min(N, lcx + lakeBox); x++)
            {
                int i = y * N + x;
                float u = ToDesign(x / (float)(N - 1)), v = ToDesign(y / (float)(N - 1));
                float d = Len(u - LAKE_U, v - LAKE_V);
                float shore = LAKE_R + 0.006f * Fbm(u * 40f, v * 40f, 2);
                float plateau = Smooth((0.07f - d) / 0.03f);
                H[i] = Lerp(H[i], lakeLevel + 3f, plateau * 0.85f);
                if (d < shore)
                {
                    H[i] = lakeLevel - 2f - 6f * Smooth(1f - d / shore);
                    W[i] = lakeLevel;
                }
                else if (d < shore + 0.008f)
                {
                    H[i] = Math.Max(H[i], lakeLevel + 1.5f);  // orilla que contiene el agua
                }
            }
        }

        // --- 3. Río: recorrido suavizado, superficie siempre descendente y cauce excavado.
        List<float[]> path = new List<float[]>();
        for (int s = 0; s < RIVER.Length - 1; s++)
        {
            float[] p0 = RIVER[Math.Max(s - 1, 0)], p1 = RIVER[s], p2 = RIVER[s + 1];
            float[] p3 = RIVER[Math.Min(s + 2, RIVER.Length - 1)];
            for (int k = 0; k < 40; k++)
            {
                float t = k / 40f, t2 = t * t, t3 = t2 * t;
                float pu = 0.5f * (2f * p1[0] + (-p0[0] + p2[0]) * t + (2f * p0[0] - 5f * p1[0] + 4f * p2[0] - p3[0]) * t2 + (-p0[0] + 3f * p1[0] - 3f * p2[0] + p3[0]) * t3);
                float pv = 0.5f * (2f * p1[1] + (-p0[1] + p2[1]) * t + (2f * p0[1] - 5f * p1[1] + 4f * p2[1] - p3[1]) * t2 + (-p0[1] + 3f * p1[1] - 3f * p2[1] + p3[1]) * t3);
                path.Add(new float[] { pu, pv });
            }
        }
        path.Add(RIVER[RIVER.Length - 1]);

        float[] surf = new float[path.Count];
        float level = lakeLevel;
        for (int s = 0; s < path.Count; s++)
        {
            float pu = path[s][0], pv = path[s][1];
            if (Len(pu - LAKE_U, pv - LAKE_V) > LAKE_R + 0.01f)
            {
                float ground = SampleBilinear(H, FromDesign(pu) * (N - 1), FromDesign(pv) * (N - 1));
                level = Math.Min(level, ground - 2.5f);
                level = Math.Max(level, SEA - 1f);
            }
            surf[s] = level;
        }

        float[] rDist = new float[count];
        float[] rSurf = new float[count];
        float[] rWidth = new float[count];
        for (int i = 0; i < count; i++) rDist[i] = float.MaxValue;
        const float BANK = 9f;
        for (int s = 0; s < path.Count; s++)
        {
            float t = s / (float)(path.Count - 1);
            float width = 3.5f + 4.5f * t;
            float pxf = FromDesign(path[s][0]) * (N - 1), pyf = FromDesign(path[s][1]) * (N - 1);
            int reach = (int)Math.Ceiling(width + BANK) + 1;
            for (int y = (int)pyf - reach; y <= (int)pyf + reach; y++)
            {
                if (y < 0 || y >= N) continue;
                for (int x = (int)pxf - reach; x <= (int)pxf + reach; x++)
                {
                    if (x < 0 || x >= N) continue;
                    float d = Len(x - pxf, y - pyf);
                    int i = y * N + x;
                    if (d < rDist[i]) { rDist[i] = d; rSurf[i] = surf[s]; rWidth[i] = width; }
                }
            }
        }
        for (int i = 0; i < count; i++)
        {
            if (rDist[i] == float.MaxValue) continue;
            if (C[i] < -0.01f) continue;  // en el mar ya no hay cauce: desemboca en la costa
            float d = rDist[i], w = rWidth[i], s = rSurf[i];
            if (d <= w)
            {
                float depth = 1.5f + 2.5f * (1f - (d / w) * (d / w));
                H[i] = Math.Min(H[i], s - depth);
                W[i] = Math.Max(W[i], s);
            }
            else if (d <= w + BANK)
            {
                H[i] = Math.Min(H[i], s + 1f + (d - w) / BANK * 7f);
            }
        }

        // --- 4. Biomas.
        int[] biomeCount = new int[PALETTE.Length];
        for (int y = 0; y < N; y++)
        {
            for (int x = 0; x < N; x++)
            {
                int i = y * N + x;
                float u = ToDesign(x / (float)(N - 1)), v = ToDesign(y / (float)(N - 1));
                float h = H[i];
                byte b;
                if (W[i] > h + 0.25f) b = WATER;
                else if (h <= SEA) b = OCEAN;
                else if (corrupt[i] > 0.5f && mountain[i] < 0.35f) b = CORRUPT;
                else if (beach[i]) b = BEACH;
                else if (village[i] > 0.5f) b = VILLAGE;
                else if (farm[i] > 0.5f) b = FARM;
                else if (h <= SEA + 2f && C[i] < 0.12f) b = BEACH;
                else if (mountain[i] > 0.12f) b = (h > 152f) ? ALPINE : PINE;
                else if (castle[i] > 0.4f) b = MEADOW;
                else b = (Fbm(u * 9f + 11f, v * 9f + 3f, 3) > -0.12f) ? FOREST : MEADOW;
                B[i] = b;
                biomeCount[b]++;
            }
        }

        // --- 5. Guardar mapas.
        byte[] heightRgb = new byte[count * 3];
        byte[] waterRgb = new byte[count * 3];
        byte[] biomeRgb = new byte[count * 3];
        byte[] previewRgb = new byte[count * 3];
        float minH = float.MaxValue, maxH = float.MinValue;
        for (int y = 0; y < N; y++)
        {
            for (int x = 0; x < N; x++)
            {
                int i = y * N + x;
                minH = Math.Min(minH, H[i]); maxH = Math.Max(maxH, H[i]);
                Encode16(heightRgb, i, H[i]);
                Encode16(waterRgb, i, W[i]);
                int[] pc = PALETTE[B[i]];
                biomeRgb[i * 3] = (byte)pc[0]; biomeRgb[i * 3 + 1] = (byte)pc[1]; biomeRgb[i * 3 + 2] = (byte)pc[2];
                PreviewColor(previewRgb, H, W, B, x, y);
            }
        }
        SaveRgb(System.IO.Path.Combine(outDir, "height.png"), heightRgb);
        SaveRgb(System.IO.Path.Combine(outDir, "water.png"), waterRgb);
        SaveRgb(System.IO.Path.Combine(outDir, "biome.png"), biomeRgb);
        SaveRgb(System.IO.Path.Combine(outDir, "preview.png"), previewRgb);
        SaveRgb(System.IO.Path.Combine(outDir, "surface.png"), BuildSurface(H, W, B));

        string[] names = { "mar", "playa", "pradera", "bosque", "pinar", "alta montaña", "corrupta", "pueblo", "campos", "río/lago" };
        string summary = String.Format("Altura min {0:F1} max {1:F1} voxels. Lago a {2} voxels.\n", minH, maxH, lakeLevel);
        for (int k = 0; k < names.Length; k++)
            summary += String.Format("  {0}: {1:F1}%\n", names[k], 100.0 * biomeCount[k] / count);
        return summary;
    }

    // Distancia (en píxeles) de cada punto al mar más cercano: transformada de distancia
    // "chamfer" en dos pasadas (rápida y suficientemente precisa).
    static float[] DistanceToSea(float[] H)
    {
        int count = N * N;
        float[] d = new float[count];
        for (int i = 0; i < count; i++) d[i] = H[i] <= SEA ? 0f : 1e9f;
        const float D1 = 1f, D2 = 1.4142f;
        for (int y = 0; y < N; y++)
            for (int x = 0; x < N; x++)
            {
                int i = y * N + x;
                if (x > 0) d[i] = Math.Min(d[i], d[i - 1] + D1);
                if (y > 0)
                {
                    d[i] = Math.Min(d[i], d[i - N] + D1);
                    if (x > 0) d[i] = Math.Min(d[i], d[i - N - 1] + D2);
                    if (x < N - 1) d[i] = Math.Min(d[i], d[i - N + 1] + D2);
                }
            }
        for (int y = N - 1; y >= 0; y--)
            for (int x = N - 1; x >= 0; x--)
            {
                int i = y * N + x;
                if (x < N - 1) d[i] = Math.Min(d[i], d[i + 1] + D1);
                if (y < N - 1)
                {
                    d[i] = Math.Min(d[i], d[i + N] + D1);
                    if (x < N - 1) d[i] = Math.Min(d[i], d[i + N + 1] + D2);
                    if (x > 0) d[i] = Math.Min(d[i], d[i + N - 1] + D2);
                }
            }
        return d;
    }

    // Aplana una franja junto al mar en una rampa suave de arena. La anchura varía a lo largo de
    // la costa (playas anchas en unos sitios, casi nada en otros) y en la montaña, la zona
    // corrupta y la colina de las ruinas la costa se queda en roca (acantilados).
    static bool[] CarveBeaches(float[] H, float[] mountain, float[] corrupt, float[] castle, float[] village)
    {
        float[] dist = DistanceToSea(H);
        bool[] beach = new bool[N * N];
        for (int y = 0; y < N; y++)
        {
            for (int x = 0; x < N; x++)
            {
                int i = y * N + x;
                float d = dist[i];
                if (d <= 0f || d > 20f) continue;
                float u = ToDesign(x / (float)(N - 1)), v = ToDesign(y / (float)(N - 1));
                float width = 2f + 14f * Smooth(Fbm(u * 7f + 13f, v * 7f + 2f, 3) * 2.2f + 0.45f);
                float rocky = Math.Max(Math.Max(mountain[i], corrupt[i]), castle[i]);
                width *= 1f - Smooth((rocky - 0.15f) / 0.3f);
                width = Math.Max(width, 14f * village[i]);  // el pueblo tiene su playa (y luego muelles)
                if (d >= width) continue;
                float t = d / width;
                float sand = SEA + 0.8f + 2.2f * t;  // la arena sube suavemente desde el agua
                H[i] = Math.Min(H[i], Lerp(sand, H[i], Smooth(t) * Smooth(t)));
                beach[i] = t < 0.8f && H[i] <= SEA + 3.5f;
            }
        }
        return beach;
    }

    // surface.png: R = bloque de la superficie, G = bloque del subsuelo,
    // B = árbol (tipo * 64 + densidad en milésimas). Así el juego no calcula nada de esto.
    static byte[] BuildSurface(float[] H, float[] W, byte[] B)
    {
        byte[] rgb = new byte[N * N * 3];
        for (int y = 0; y < N; y++)
        {
            for (int x = 0; x < N; x++)
            {
                int i = y * N + x;
                float u = ToDesign(x / (float)(N - 1)), v = ToDesign(y / (float)(N - 1));
                float h = H[i];
                byte biome = B[i];
                // Pendiente medida sobre ±2 píxeles (8 voxels): con vecinos inmediatos, en una
                // ladera media cada bloque caía a un lado u otro del umbral y salía "moteado".
                int xl = Math.Max(x - 2, 0), xr = Math.Min(x + 2, N - 1);
                int yu = Math.Max(y - 2, 0), yd = Math.Min(y + 2, N - 1);
                float slope = Math.Max(Math.Abs(H[y * N + xr] - H[y * N + xl]) / ((xr - xl) * VOXELS_PER_PX),
                                       Math.Abs(H[yd * N + x] - H[yu * N + x]) / ((yd - yu) * VOXELS_PER_PX));
                bool steep = slope > STEEP;
                // Borde de la nieve en manchas grandes (no en puntitos).
                float snowLine = SNOW + Fbm(u * 14f + 3f, v * 14f + 8f, 3) * 14f;

                byte top, sub;
                switch (biome)
                {
                    case OCEAN: top = h > SEA - 12f ? BL_SAND : BL_STONE; sub = BL_SAND; break;
                    case BEACH: top = BL_SAND; sub = BL_SAND; break;
                    case WATER: top = BL_DIRT; sub = BL_DIRT; break;  // fondo oscuro: el agua parece más profunda
                    case CORRUPT:
                        if (steep) { top = BL_STONE; sub = BL_STONE; } else { top = BL_CORRUPT_SOIL; sub = BL_DIRT; }
                        break;
                    case FARM: top = ((x >> 1) & 1) == 0 ? BL_WHEAT : BL_DIRT; sub = BL_DIRT; break;  // surcos
                    case ALPINE:
                        if (h >= snowLine && !steep) { top = BL_SNOW; sub = BL_STONE; } else { top = BL_STONE; sub = BL_STONE; }
                        break;
                    default:
                        if (h >= snowLine) { top = steep ? BL_STONE : BL_SNOW; sub = BL_STONE; }
                        else if (steep) { top = BL_STONE; sub = BL_STONE; }
                        else { top = BL_GRASS; sub = BL_DIRT; }
                        break;
                }

                float density = 0f; int kind = TREE_BROAD;
                switch (biome)
                {
                    case FOREST: density = 0.045f; break;
                    case MEADOW: density = 0.005f; break;
                    case VILLAGE: density = 0.002f; break;
                    case PINE: density = 0.035f; kind = TREE_PINE; break;
                    case ALPINE: density = 0.006f; kind = TREE_PINE; break;
                    case CORRUPT: density = 0.012f; kind = TREE_DEAD; break;
                }
                if (h <= SEA + 1f || h >= TREE_LINE + 10f || W[i] > h || slope > 0.8f) density = 0f;
                int tree = density > 0f ? kind * 64 + Math.Min(63, (int)Math.Round(density * 1000f)) : 0;

                rgb[i * 3] = top;
                rgb[i * 3 + 1] = sub;
                rgb[i * 3 + 2] = (byte)tree;
            }
        }
        return rgb;
    }

    static void Encode16(byte[] rgb, int i, float value)
    {
        int q = (int)Math.Round(value * 64f);
        if (q < 0) q = 0; if (q > 65535) q = 65535;
        rgb[i * 3] = (byte)(q >> 8);
        rgb[i * 3 + 1] = (byte)(q & 255);
        rgb[i * 3 + 2] = 0;
    }

    static void PreviewColor(byte[] rgb, float[] H, float[] W, byte[] B, int x, int y)
    {
        int i = y * N + x;
        float h = H[i];
        float r, g, b;
        byte biome = B[i];
        if (biome == OCEAN)
        {
            float depth = Clamp01((SEA - h) / 18f);
            r = Lerp(70, 15, depth); g = Lerp(200, 55, depth); b = Lerp(200, 130, depth);
        }
        else if (biome == WATER) { r = 70; g = 190; b = 220; }
        else
        {
            int[] pc = PALETTE[biome];
            r = pc[0]; g = pc[1]; b = pc[2];
            int xl = Math.Max(x - 1, 0), xr = Math.Min(x + 1, N - 1);
            int yu = Math.Max(y - 1, 0), yd = Math.Min(y + 1, N - 1);
            float sx = (H[y * N + xr] - H[y * N + xl]) / (2f * VOXELS_PER_PX);
            float sy = (H[yd * N + x] - H[yu * N + x]) / (2f * VOXELS_PER_PX);
            bool steep = Math.Max(Math.Abs(sx), Math.Abs(sy)) > 1.0f;
            if (biome == ALPINE || biome == PINE)
            {
                if (h > SNOW) { r = 245; g = 247; b = 250; }
                else if (biome == ALPINE || steep) { r = 140; g = 140; b = 145; }
            }
            else if (steep && biome != BEACH) { r = 130; g = 128; b = 125; }

            // Sombreado de relieve con luz del noroeste (exagerado para leer bien el relieve).
            float nx = -sx * 2.5f, ny = 1f, nz = -sy * 2.5f;
            float nl = (float)Math.Sqrt(nx * nx + ny * ny + nz * nz);
            float shade = (nx * -0.55f + ny * 0.65f + nz * -0.55f) / nl;
            float k = 0.35f + 0.9f * shade;
            r *= k; g *= k; b *= k;
        }
        rgb[i * 3] = (byte)Math.Max(0, Math.Min(255, (int)r));
        rgb[i * 3 + 1] = (byte)Math.Max(0, Math.Min(255, (int)g));
        rgb[i * 3 + 2] = (byte)Math.Max(0, Math.Min(255, (int)b));
    }

    static void SaveRgb(string path, byte[] rgb)
    {
        using (Bitmap bmp = new Bitmap(N, N, PixelFormat.Format24bppRgb))
        {
            BitmapData data = bmp.LockBits(new Rectangle(0, 0, N, N), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
            byte[] row = new byte[data.Stride * N];
            for (int y = 0; y < N; y++)
            {
                for (int x = 0; x < N; x++)
                {
                    int s = (y * N + x) * 3;
                    int d = y * data.Stride + x * 3;
                    row[d] = rgb[s + 2];      // GDI guarda en orden BGR
                    row[d + 1] = rgb[s + 1];
                    row[d + 2] = rgb[s];
                }
            }
            Marshal.Copy(row, 0, data.Scan0, row.Length);
            bmp.UnlockBits(data);
            bmp.Save(path, ImageFormat.Png);
        }
    }
}
