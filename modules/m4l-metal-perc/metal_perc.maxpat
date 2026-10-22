{
 "patcher": {
  "fileversion": 1,
  "appversion": {
   "major": 8,
   "minor": 6,
   "revision": 0,
   "architecture": "x64",
   "modernui": 1
  },
  "classnamespace": "box",
  "rect": [
   60,
   80,
   1300,
   900
  ],
  "openinpresentation": 1,
  "devicewidth": 975,
  "default_fontsize": 10.0,
  "boxes": [
   {
    "box": {
     "maxclass": "newobj",
     "text": "gen~",
     "numinlets": 5,
     "numoutlets": 4,
     "outlettype": [
      "signal",
      "signal",
      "signal",
      "signal"
     ],
     "patching_rect": [
      40,
      1000,
      300,
      22
     ],
     "patcher": {
      "fileversion": 1,
      "appversion": {
       "major": 8,
       "minor": 6,
       "revision": 0,
       "architecture": "x64",
       "modernui": 1
      },
      "classnamespace": "dsp.gen",
      "rect": [
       100,
       100,
       820,
       740
      ],
      "boxes": [
       {
        "box": {
         "maxclass": "newobj",
         "text": "in 1",
         "numinlets": 0,
         "numoutlets": 1,
         "outlettype": [
          ""
         ],
         "patching_rect": [
          20,
          20,
          40,
          22
         ],
         "id": "obj-1"
        }
       },
       {
        "box": {
         "maxclass": "newobj",
         "text": "in 2",
         "numinlets": 0,
         "numoutlets": 1,
         "outlettype": [
          ""
         ],
         "patching_rect": [
          130,
          20,
          40,
          22
         ],
         "id": "obj-2"
        }
       },
       {
        "box": {
         "maxclass": "newobj",
         "text": "in 3",
         "numinlets": 0,
         "numoutlets": 1,
         "outlettype": [
          ""
         ],
         "patching_rect": [
          240,
          20,
          40,
          22
         ],
         "id": "obj-3"
        }
       },
       {
        "box": {
         "maxclass": "newobj",
         "text": "in 4",
         "numinlets": 0,
         "numoutlets": 1,
         "outlettype": [
          ""
         ],
         "patching_rect": [
          350,
          20,
          40,
          22
         ],
         "id": "obj-4"
        }
       },
       {
        "box": {
         "maxclass": "newobj",
         "text": "in 5",
         "numinlets": 0,
         "numoutlets": 1,
         "outlettype": [
          ""
         ],
         "patching_rect": [
          460,
          20,
          40,
          22
         ],
         "id": "obj-5"
        }
       },
       {
        "box": {
         "maxclass": "codebox",
         "code": "// =====================================================================\n// m4l-metal-perc – metallischer Percussion-Generator mit Step-Sequencer\n// gen~ Codebox (GenExpr). Diese Datei wird von build.py erzeugt:\n// Quelle ist src/metal_perc.genexpr.in – dort editieren, nicht hier.\n//\n// Eingänge  (Signal, Konvention: ±1.0 = ±5 V)\n//   in1  Host-Beat-Phase (plugphasor~, 0..1 pro Beat)\n//   in2  Ext Clock (steigende Flanke = 1 Step)\n//   in3  Ext Reset (steigende Flanke)\n//   in4  Pitch CV, 1 V/Oct (0.2 = 1 Oktave), wird beim Trigger gehalten\n//   in5  Ext Trigger (spielt die Voice direkt, unabhängig vom Sequencer)\n// Ausgänge\n//   out1 Audio\n//   out2 Hüllkurve (0..1)\n//   out3 aktueller Step (0..15)\n//   out4 Gate/Trigger-Out (5 ms)\n// =====================================================================\n\n// ---------- Hilfsfunktionen ----------\nblep(t, dt) {\n\tr = 0;\n\tif (t < dt) {\n\t\tx = t / dt;\n\t\tr = x + x - x * x - 1;\n\t} else if (t > 1 - dt) {\n\t\tx = (t - 1) / dt;\n\t\tr = x * x + x + x + 1;\n\t}\n\treturn r;\n}\n\n// w: 0 Sine, 1 Square, 2 Saw, 3 Triangle (bandbegrenzt via polyBLEP)\nosc(p, dt, w) {\n\ty = 0;\n\tif (w < 0.5) {\n\t\ty = sin(twopi * p);\n\t} else if (w < 1.5) {\n\t\tsq = 1;\n\t\tif (p >= 0.5) {\n\t\t\tsq = -1;\n\t\t}\n\t\ty = sq + blep(p, dt) - blep(fract(p + 0.5), dt);\n\t} else if (w < 2.5) {\n\t\ty = 2 * p - 1 - blep(p, dt);\n\t} else {\n\t\ty = 4 * abs(p - 0.5) - 1;\n\t}\n\treturn y;\n}\n\n// Nächstliegende Note in der Skala (mask = 12-Bit-Maske ab Grundton)\nquant(n, root, mask) {\n\tbase = floor(n + 0.5);\n\tbest = base;\n\tbestd = 100;\n\tfor (k = -6; k <= 6; k += 1) {\n\t\tcand = base + k;\n\t\tdeg = cand - root;\n\t\tdeg = deg - floor(deg / 12) * 12;\n\t\tbit = floor(mask / pow(2, deg));\n\t\tbit = bit - floor(bit / 2) * 2;\n\t\td = abs(cand - n);\n\t\tif (bit > 0.5 && d < bestd) {\n\t\t\tbest = cand;\n\t\t\tbestd = d;\n\t\t}\n\t}\n\treturn best;\n}\n\n// TPT-State-Variable-Filter: liefert Bandpass (unity peak) bzw. Highpass,\n// Zustände liegen in Data st an Index i und i+1.\nsvf_bp(x, fc, q, st, i) {\n\tg = tan(pi * fc / samplerate);\n\tk = 1 / q;\n\ta1 = 1 / (1 + g * (g + k));\n\ta2 = g * a1;\n\ta3 = g * a2;\n\tic1 = peek(st, i);\n\tic2 = peek(st, i + 1);\n\tv3 = x - ic2;\n\tv1 = a1 * ic1 + a2 * v3;\n\tv2 = ic2 + a2 * ic1 + a3 * v3;\n\tpoke(st, 2 * v1 - ic1, i);\n\tpoke(st, 2 * v2 - ic2, i + 1);\n\treturn v1 * k;\n}\n\nsvf_hp(x, fc, q, st, i) {\n\tg = tan(pi * fc / samplerate);\n\tk = 1 / q;\n\ta1 = 1 / (1 + g * (g + k));\n\ta2 = g * a1;\n\ta3 = g * a2;\n\tic1 = peek(st, i);\n\tic2 = peek(st, i + 1);\n\tv3 = x - ic2;\n\tv1 = a1 * ic1 + a2 * v3;\n\tv2 = ic2 + a2 * ic1 + a3 * v3;\n\tpoke(st, 2 * v1 - ic1, i);\n\tpoke(st, 2 * v2 - ic2, i + 1);\n\treturn x - k * v1 - v2;\n}\n\n// ---------- Parameter: Voice ----------\nParam tune(56, min=24, max=96);       // Basis-Note (MIDI)\nParam waveform(1, min=0, max=3);          // 0 Sine 1 Square 2 Saw 3 Tri\nParam morph(0, min=0, max=1);         // 0 Bank -> 0.5 FM/Ring -> 1 Resonator\nParam inharm(0.5, min=0, max=1);      // 0 harmonisch -> 0.5 808-Metall -> 1 Membran/Glocke\nParam decay(0.3, min=0, max=1);       // 10 ms .. 2.5 s\nParam damp(0.5, min=0, max=1);        // Resonator-Dämpfung\nParam bright(0.6, min=0, max=1);      // Filter/FM-Index\nParam drive(0.2, min=0, max=1);\nParam noise_mix(0.05, min=0, max=1);\nParam accent(0.5, min=0, max=1);      // Velocity -> Decay/Helligkeit\nParam level(0.8, min=0, max=1);\n\n// ---------- Parameter: Pitch / Quantizer ----------\nParam qmode(1, min=0, max=1);         // 0 Loose, 1 Scale\nParam scale_sel(1, min=0, max=7);\nParam root(0, min=0, max=11);\n\n// ---------- Parameter: Sequencer ----------\nParam seq_on(1, min=0, max=1);\nParam clock_mode(0, min=0, max=2);    // 0 Host, 1 Ext Clock, 2 Intern\nParam bpm(130, min=40, max=300);\nParam clock_div(1, min=0, max=4);           // 1/8, 1/16, 1/32, 1/8T, 1/16T\nParam seq_len(16, min=1, max=16);\nParam reset_id(0);\n\n// ---------- Parameter: Live-Randomisierung ----------\nParam live_steps(0, min=0, max=1);\nParam live_vel(0, min=0, max=1);\nParam live_pitch(0, min=0, max=1);\nParam density(0.6, min=0, max=1);\nParam vel_range(0.5, min=0, max=1);\nParam pitch_range(7, min=0, max=24);\n\n// ---------- Parameter: MIDI ----------\nParam midi_id(0);\nParam midi_note(60);\nParam midi_vel(0);\n\n// ---------- Parameter: Steps ----------\nParam s1_on(1, min=0, max=1); Param s1_vel(1, min=0, max=1); Param s1_pitch(0, min=-24, max=24);\nParam s2_on(1, min=0, max=1); Param s2_vel(1, min=0, max=1); Param s2_pitch(0, min=-24, max=24);\nParam s3_on(1, min=0, max=1); Param s3_vel(1, min=0, max=1); Param s3_pitch(0, min=-24, max=24);\nParam s4_on(1, min=0, max=1); Param s4_vel(1, min=0, max=1); Param s4_pitch(0, min=-24, max=24);\nParam s5_on(1, min=0, max=1); Param s5_vel(1, min=0, max=1); Param s5_pitch(0, min=-24, max=24);\nParam s6_on(1, min=0, max=1); Param s6_vel(1, min=0, max=1); Param s6_pitch(0, min=-24, max=24);\nParam s7_on(1, min=0, max=1); Param s7_vel(1, min=0, max=1); Param s7_pitch(0, min=-24, max=24);\nParam s8_on(1, min=0, max=1); Param s8_vel(1, min=0, max=1); Param s8_pitch(0, min=-24, max=24);\nParam s9_on(1, min=0, max=1); Param s9_vel(1, min=0, max=1); Param s9_pitch(0, min=-24, max=24);\nParam s10_on(1, min=0, max=1); Param s10_vel(1, min=0, max=1); Param s10_pitch(0, min=-24, max=24);\nParam s11_on(1, min=0, max=1); Param s11_vel(1, min=0, max=1); Param s11_pitch(0, min=-24, max=24);\nParam s12_on(1, min=0, max=1); Param s12_vel(1, min=0, max=1); Param s12_pitch(0, min=-24, max=24);\nParam s13_on(1, min=0, max=1); Param s13_vel(1, min=0, max=1); Param s13_pitch(0, min=-24, max=24);\nParam s14_on(1, min=0, max=1); Param s14_vel(1, min=0, max=1); Param s14_pitch(0, min=-24, max=24);\nParam s15_on(1, min=0, max=1); Param s15_vel(1, min=0, max=1); Param s15_pitch(0, min=-24, max=24);\nParam s16_on(1, min=0, max=1); Param s16_vel(1, min=0, max=1); Param s16_pitch(0, min=-24, max=24);\n\n// ---------- Zustand ----------\nHistory beats(0);\nHistory last_phase(-1);\nHistory still(0);\nHistory int_phase(0);\nHistory ext_count(0);\nHistory clk_prev(0);\nHistory rst_prev(0);\nHistory trg_prev(0);\nHistory last_reset(0);\nHistory last_midi(0);\nHistory last_step(-1);\nHistory env(0);\nHistory coef(0.999);\nHistory exc(0);\nHistory hit_note(56);\nHistory hit_vel(1);\nHistory gate_cnt(0);\nHistory dc_x(0);\nHistory dc_y(0);\nData ph(8);     // Phasen: 0-5 Bank, 6 Träger, 7 Modulator\nData st(16);    // Filterzustände\n\n// ---------- Clock ----------\nspb = selector(floor(clock_div) + 1, 2, 4, 8, 3, 6);  // Steps pro Beat\nlen = floor(seq_len);\n\nif (reset_id != last_reset) {\n\tlast_reset = reset_id;\n\tbeats = 0;\n\tint_phase = 0;\n\text_count = 0;\n\tlast_step = -1;\n}\nrst = in3 > 0.1;\nif (rst && rst_prev < 0.5) {\n\tbeats = 0;\n\tint_phase = 0;\n\text_count = 0;\n\tlast_step = -1;\n}\nrst_prev = rst;\n\nstep_abs = -1;\nif (clock_mode < 0.5) {\n\tphs = in1;\n\t// Transport-Stopp erkennen: Phase steht > 50 ms -> beim Weiterlaufen neu ab Step 1\n\tif (phs == last_phase) {\n\t\tstill = still + 1;\n\t} else {\n\t\tif (still > samplerate * 0.05) {\n\t\t\tbeats = 0;\n\t\t\tlast_step = -1;\n\t\t} else if (phs < last_phase - 0.5) {\n\t\t\tbeats = beats + 1;\n\t\t}\n\t\tstill = 0;\n\t}\n\tlast_phase = phs;\n\tif (still < samplerate * 0.05) {\n\t\tstep_abs = floor((beats + phs) * spb);\n\t} else {\n\t\tstep_abs = last_step;\n\t}\n} else if (clock_mode < 1.5) {\n\tc = in2 > 0.1;\n\tif (c && clk_prev < 0.5) {\n\t\text_count = ext_count + 1;\n\t}\n\tclk_prev = c;\n\tstep_abs = ext_count - 1;\n} else {\n\tint_phase = int_phase + bpm / 60 / samplerate;\n\tstep_abs = floor(int_phase * spb);\n}\n\ncur_step = last_step;\nfire = 0;\nvel = 1;\npitch = 0;\nif (step_abs >= 0) {\n\tcur = step_abs - floor(step_abs / len) * len;\n\tif (cur != last_step) {\n\t\tlast_step = cur;\n\t\tcur_step = cur;\n\t\ton = selector(cur + 1, s1_on, s2_on, s3_on, s4_on, s5_on, s6_on, s7_on, s8_on, s9_on, s10_on, s11_on, s12_on, s13_on, s14_on, s15_on, s16_on);\n\t\tif (seq_on > 0.5 && on > 0.5) {\n\t\t\tif (live_steps < 0.5 || (noise() * 0.5 + 0.5) < density) {\n\t\t\t\tfire = 1;\n\t\t\t\tvel = selector(cur + 1, s1_vel, s2_vel, s3_vel, s4_vel, s5_vel, s6_vel, s7_vel, s8_vel, s9_vel, s10_vel, s11_vel, s12_vel, s13_vel, s14_vel, s15_vel, s16_vel);\n\t\t\t\tpitch = selector(cur + 1, s1_pitch, s2_pitch, s3_pitch, s4_pitch, s5_pitch, s6_pitch, s7_pitch, s8_pitch, s9_pitch, s10_pitch, s11_pitch, s12_pitch, s13_pitch, s14_pitch, s15_pitch, s16_pitch);\n\t\t\t\tif (live_vel > 0.5) {\n\t\t\t\t\tvel = vel * (1 - vel_range * (noise() * 0.5 + 0.5));\n\t\t\t\t}\n\t\t\t\tif (live_pitch > 0.5) {\n\t\t\t\t\tpitch = pitch + pitch_range * noise();\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n}\n\n// MIDI-Noten (aus Live-Clips) und Ext Trigger spielen die Voice direkt\nif (midi_id != last_midi) {\n\tlast_midi = midi_id;\n\tif (midi_vel > 0) {\n\t\tfire = 1;\n\t\tvel = midi_vel / 127;\n\t\tpitch = midi_note - 60;\n\t}\n}\ntr = in5 > 0.1;\nif (tr && trg_prev < 0.5) {\n\tfire = 1;\n\tvel = 1;\n\tpitch = 0;\n}\ntrg_prev = tr;\n\n// ---------- Trigger -> Voice ----------\nif (fire > 0.5) {\n\tnote = tune + pitch + in4 * 60;\n\tif (qmode > 0.5) {\n\t\tmask = selector(floor(scale_sel) + 1, 4095, 1453, 1451, 2477, 1193, 1709, 1459, 397);\n\t\tnote = quant(note, root, mask);\n\t}\n\thit_note = note;\n\thit_vel = vel;\n\tt = 0.01 * pow(250, decay);\n\tt = t * (1 - accent * 0.5 + accent * vel);\n\tcoef = exp(-6.9078 / (t * samplerate));\n\tenv = max(env, vel);\n\texc = 1;\n\tgate_cnt = samplerate * 0.005;\n}\n\nenv = env * coef;\nexc = exc * 0.992;\nif (gate_cnt > 0) {\n\tgate_cnt = gate_cnt - 1;\n}\n\nf0 = mtof(hit_note);\nnyq = samplerate * 0.45;\nw = floor(waveform + 0.5);\nacc_b = bright * (1 - accent * 0.4 + accent * 0.4 * hit_vel);\n\n// ---------- Engine A: Oszillator-Bank (6 Oszillatoren) ----------\nta = clamp(inharm * 2, 0, 1);\ntb = clamp(inharm * 2 - 1, 0, 1);\nbank = 0;\nfor (i = 0; i < 6; i += 1) {\n\trh = i + 1;\n\trm = selector(i + 1, 1, 1.483, 1.8, 2.546, 2.63, 3.897);\n\tre = selector(i + 1, 1, 1.593, 2.135, 2.296, 2.917, 3.598);\n\tratio = mix(mix(rh, rm, ta), re, tb);\n\tinc = min(f0 * ratio / samplerate, 0.45);\n\tp = peek(ph, i);\n\tbank = bank + osc(p, inc, w);\n\tpoke(ph, fract(p + inc), i);\n}\nbank = bank / 6;\nfca = min(f0 * mix(2, 24, acc_b) * (0.4 + 0.6 * sqrt(env)), nyq);\neng_a = 1.8 * svf_bp(bank, fca, 1.5, st, 0) + 1.8 * svf_hp(bank, fca, 0.7, st, 2);\n\n// ---------- Engine B: FM / Ringmodulation ----------\nrmod = mix(mix(2, 1.4142, ta), 3.7321, tb);\ninc_c = min(f0 / samplerate, 0.45);\ninc_m = min(f0 * rmod / samplerate, 0.45);\npc = peek(ph, 6);\npm = peek(ph, 7);\nmods = osc(pm, inc_m, w);\nidx = acc_b * 1.2 * env;\ncar = osc(fract(pc + idx * mods + 1), inc_c, w);\nring = osc(pc, inc_c, w) * mods;\npoke(ph, fract(pc + inc_c), 6);\npoke(ph, fract(pm + inc_m), 7);\neng_b = 0.7 * car + 0.5 * ring;\n\n// ---------- Engine C: Resonator-Bank (4 Moden, angeregt durch Rauschimpuls) ----------\nex = noise() * exc * exc * (0.4 + 0.6 * acc_b) * hit_vel;\nq = mix(400, 12, damp);\nres = 0;\nfor (j = 0; j < 4; j += 1) {\n\tmh = j + 1;\n\tmb = selector(j + 1, 1, 2.756, 5.404, 8.933);\n\tmp = selector(j + 1, 1, 1.594, 2.136, 2.653);\n\tmr = mix(mix(mh, mb, ta), mp, tb);\n\tfr = min(f0 * mr, nyq);\n\tres = res + svf_bp(ex, fr, q, st, 4 + j * 2) * sqrt(1000 / fr) / (j + 1);\n}\neng_c = res * sqrt(q) * 15 * min(1, env * 4);\n\n// ---------- Morph, Noise, Drive ----------\nva = eng_a * env;\nvb = eng_b * env;\nm = morph * 2;\nvoice = 0;\nif (m < 1) {\n\tvoice = va * cos(m * pi * 0.5) + vb * sin(m * pi * 0.5);\n} else {\n\tm = m - 1;\n\tvoice = vb * cos(m * pi * 0.5) + eng_c * sin(m * pi * 0.5);\n}\nnz = svf_hp(noise(), min(f0 * 8, nyq), 0.7, st, 12) * env * noise_mix;\nx = voice + nz;\n\ng = 1 + drive * 12;\ny = tanh(x * g) / sqrt(g);\n\n// DC-Blocker\ndc_y = y - dc_x + 0.995 * dc_y;\ndc_x = y;\n\nout1 = dc_y * level;\nout2 = env;\nout3 = max(cur_step, 0);\nout4 = gate_cnt > 0;\n",
         "fontface": 0,
         "fontname": "<Monospaced>",
         "fontsize": 12,
         "numinlets": 5,
         "numoutlets": 4,
         "outlettype": [
          "",
          "",
          "",
          ""
         ],
         "patching_rect": [
          20,
          60,
          760,
          600
         ],
         "id": "obj-6"
        }
       },
       {
        "box": {
         "maxclass": "newobj",
         "text": "out 1",
         "numinlets": 1,
         "numoutlets": 0,
         "patching_rect": [
          20,
          680,
          40,
          22
         ],
         "id": "obj-7"
        }
       },
       {
        "box": {
         "maxclass": "newobj",
         "text": "out 2",
         "numinlets": 1,
         "numoutlets": 0,
         "patching_rect": [
          130,
          680,
          40,
          22
         ],
         "id": "obj-8"
        }
       },
       {
        "box": {
         "maxclass": "newobj",
         "text": "out 3",
         "numinlets": 1,
         "numoutlets": 0,
         "patching_rect": [
          240,
          680,
          40,
          22
         ],
         "id": "obj-9"
        }
       },
       {
        "box": {
         "maxclass": "newobj",
         "text": "out 4",
         "numinlets": 1,
         "numoutlets": 0,
         "patching_rect": [
          350,
          680,
          40,
          22
         ],
         "id": "obj-10"
        }
       }
      ],
      "lines": [
       {
        "patchline": {
         "source": [
          "obj-1",
          0
         ],
         "destination": [
          "obj-6",
          0
         ]
        }
       },
       {
        "patchline": {
         "source": [
          "obj-2",
          0
         ],
         "destination": [
          "obj-6",
          1
         ]
        }
       },
       {
        "patchline": {
         "source": [
          "obj-3",
          0
         ],
         "destination": [
          "obj-6",
          2
         ]
        }
       },
       {
        "patchline": {
         "source": [
          "obj-4",
          0
         ],
         "destination": [
          "obj-6",
          3
         ]
        }
       },
       {
        "patchline": {
         "source": [
          "obj-5",
          0
         ],
         "destination": [
          "obj-6",
          4
         ]
        }
       },
       {
        "patchline": {
         "source": [
          "obj-6",
          0
         ],
         "destination": [
          "obj-7",
          0
         ]
        }
       },
       {
        "patchline": {
         "source": [
          "obj-6",
          1
         ],
         "destination": [
          "obj-8",
          0
         ]
        }
       },
       {
        "patchline": {
         "source": [
          "obj-6",
          2
         ],
         "destination": [
          "obj-9",
          0
         ]
        }
       },
       {
        "patchline": {
         "source": [
          "obj-6",
          3
         ],
         "destination": [
          "obj-10",
          0
         ]
        }
       }
      ]
     },
     "id": "obj-1"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "plugphasor~",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      "signal"
     ],
     "patching_rect": [
      40,
      940,
      89,
      22
     ],
     "id": "obj-2"
    }
   },
   {
    "box": {
     "maxclass": "live.gain~",
     "varname": "out_gain",
     "numinlets": 2,
     "numoutlets": 5,
     "outlettype": [
      "signal",
      "signal",
      "",
      "float",
      "list"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      925,
      404,
      44,
      160
     ],
     "presentation": 1,
     "presentation_rect": [
      925,
      4,
      44,
      160
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Output",
       "parameter_shortname": "Output",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -70.0,
       "parameter_mmax": 6.0,
       "parameter_unitstyle": 4
      }
     },
     "id": "obj-3"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "plugout~ 1 2",
     "numinlets": 2,
     "numoutlets": 0,
     "outlettype": [],
     "patching_rect": [
      40,
      1100,
      96,
      22
     ],
     "id": "obj-4"
    }
   },
   {
    "box": {
     "maxclass": "live.tab",
     "varname": "step_led",
     "numinlets": 1,
     "numoutlets": 3,
     "outlettype": [
      "",
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      48,
      402,
      384,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      48,
      2,
      384,
      14
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Step LED",
       "parameter_shortname": "Step LED",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 2,
       "parameter_enum": [
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "10",
        "11",
        "12",
        "13",
        "14",
        "15",
        "16"
       ],
       "parameter_mmax": 15
      }
     },
     "num_lines_presentation": 1,
     "num_lines_patching": 1,
     "id": "obj-5"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "snapshot~ 30",
     "numinlets": 2,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      400,
      1060,
      96,
      22
     ],
     "id": "obj-6"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "change",
     "numinlets": 1,
     "numoutlets": 3,
     "outlettype": [
      "",
      "int",
      "int"
     ],
     "patching_rect": [
      400,
      1085,
      54,
      22
     ],
     "id": "obj-7"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend set",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      400,
      1110,
      89,
      22
     ],
     "id": "obj-8"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "midiin",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      700,
      940,
      54,
      22
     ],
     "id": "obj-9"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "midiparse",
     "numinlets": 1,
     "numoutlets": 8,
     "outlettype": [
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      ""
     ],
     "patching_rect": [
      700,
      965,
      75,
      22
     ],
     "id": "obj-10"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "t b l",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      ""
     ],
     "patching_rect": [
      700,
      990,
      47,
      22
     ],
     "id": "obj-11"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "unpack 0 0",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      ""
     ],
     "patching_rect": [
      760,
      1015,
      82,
      22
     ],
     "id": "obj-12"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "counter 0 0 1",
     "numinlets": 3,
     "numoutlets": 4,
     "outlettype": [
      "",
      "",
      "",
      ""
     ],
     "patching_rect": [
      700,
      1040,
      103,
      22
     ],
     "id": "obj-13"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend midi_note",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      760,
      1065,
      131,
      22
     ],
     "id": "obj-14"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend midi_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      860,
      1065,
      124,
      22
     ],
     "id": "obj-15"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend midi_id",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      700,
      1090,
      117,
      22
     ],
     "id": "obj-16"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "STEP",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      4,
      420,
      40,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      4,
      20,
      40,
      14
     ],
     "id": "obj-17"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "VEL",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      4,
      446,
      40,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      4,
      46,
      40,
      14
     ],
     "id": "obj-18"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "PITCH",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      4,
      478,
      44,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      4,
      78,
      44,
      14
     ],
     "id": "obj-19"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s1_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      52,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      52,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S1 On",
       "parameter_shortname": "S1 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-20"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s1_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      48,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      48,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S1 Vel",
       "parameter_shortname": "Vel1",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-21"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s1_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      48,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      48,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S1 Pitch",
       "parameter_shortname": "Pit1",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-22"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s1_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      40,
      1200,
      103,
      22
     ],
     "id": "obj-23"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s1_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      40,
      1230,
      110,
      22
     ],
     "id": "obj-24"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s1_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      40,
      1260,
      124,
      22
     ],
     "id": "obj-25"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s2_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      76,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      76,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S2 On",
       "parameter_shortname": "S2 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-26"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s2_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      72,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      72,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S2 Vel",
       "parameter_shortname": "Vel2",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-27"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s2_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      72,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      72,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S2 Pitch",
       "parameter_shortname": "Pit2",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-28"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s2_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      180,
      1200,
      103,
      22
     ],
     "id": "obj-29"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s2_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      180,
      1230,
      110,
      22
     ],
     "id": "obj-30"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s2_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      180,
      1260,
      124,
      22
     ],
     "id": "obj-31"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s3_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      100,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      100,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S3 On",
       "parameter_shortname": "S3 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-32"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s3_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      96,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      96,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S3 Vel",
       "parameter_shortname": "Vel3",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-33"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s3_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      96,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      96,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S3 Pitch",
       "parameter_shortname": "Pit3",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-34"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s3_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      320,
      1200,
      103,
      22
     ],
     "id": "obj-35"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s3_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      320,
      1230,
      110,
      22
     ],
     "id": "obj-36"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s3_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      320,
      1260,
      124,
      22
     ],
     "id": "obj-37"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s4_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      124,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      124,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S4 On",
       "parameter_shortname": "S4 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-38"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s4_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      120,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      120,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S4 Vel",
       "parameter_shortname": "Vel4",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-39"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s4_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      120,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      120,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S4 Pitch",
       "parameter_shortname": "Pit4",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-40"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s4_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      460,
      1200,
      103,
      22
     ],
     "id": "obj-41"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s4_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      460,
      1230,
      110,
      22
     ],
     "id": "obj-42"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s4_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      460,
      1260,
      124,
      22
     ],
     "id": "obj-43"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s5_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      148,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      148,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S5 On",
       "parameter_shortname": "S5 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-44"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s5_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      144,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      144,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S5 Vel",
       "parameter_shortname": "Vel5",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-45"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s5_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      144,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      144,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S5 Pitch",
       "parameter_shortname": "Pit5",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-46"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s5_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      600,
      1200,
      103,
      22
     ],
     "id": "obj-47"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s5_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      600,
      1230,
      110,
      22
     ],
     "id": "obj-48"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s5_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      600,
      1260,
      124,
      22
     ],
     "id": "obj-49"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s6_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      172,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      172,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S6 On",
       "parameter_shortname": "S6 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-50"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s6_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      168,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      168,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S6 Vel",
       "parameter_shortname": "Vel6",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-51"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s6_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      168,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      168,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S6 Pitch",
       "parameter_shortname": "Pit6",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-52"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s6_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      740,
      1200,
      103,
      22
     ],
     "id": "obj-53"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s6_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      740,
      1230,
      110,
      22
     ],
     "id": "obj-54"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s6_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      740,
      1260,
      124,
      22
     ],
     "id": "obj-55"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s7_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      196,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      196,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S7 On",
       "parameter_shortname": "S7 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-56"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s7_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      192,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      192,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S7 Vel",
       "parameter_shortname": "Vel7",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-57"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s7_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      192,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      192,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S7 Pitch",
       "parameter_shortname": "Pit7",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-58"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s7_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      880,
      1200,
      103,
      22
     ],
     "id": "obj-59"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s7_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      880,
      1230,
      110,
      22
     ],
     "id": "obj-60"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s7_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      880,
      1260,
      124,
      22
     ],
     "id": "obj-61"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s8_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      220,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      220,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S8 On",
       "parameter_shortname": "S8 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-62"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s8_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      216,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      216,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S8 Vel",
       "parameter_shortname": "Vel8",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-63"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s8_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      216,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      216,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S8 Pitch",
       "parameter_shortname": "Pit8",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-64"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s8_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1020,
      1200,
      103,
      22
     ],
     "id": "obj-65"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s8_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1020,
      1230,
      110,
      22
     ],
     "id": "obj-66"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s8_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1020,
      1260,
      124,
      22
     ],
     "id": "obj-67"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s9_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      244,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      244,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S9 On",
       "parameter_shortname": "S9 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-68"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s9_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      240,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      240,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S9 Vel",
       "parameter_shortname": "Vel9",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-69"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s9_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      240,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      240,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S9 Pitch",
       "parameter_shortname": "Pit9",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-70"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s9_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1160,
      1200,
      103,
      22
     ],
     "id": "obj-71"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s9_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1160,
      1230,
      110,
      22
     ],
     "id": "obj-72"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s9_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1160,
      1260,
      124,
      22
     ],
     "id": "obj-73"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s10_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      268,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      268,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S10 On",
       "parameter_shortname": "S10 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-74"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s10_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      264,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      264,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S10 Vel",
       "parameter_shortname": "Vel10",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-75"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s10_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      264,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      264,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S10 Pitch",
       "parameter_shortname": "Pit10",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-76"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s10_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1300,
      1200,
      110,
      22
     ],
     "id": "obj-77"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s10_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1300,
      1230,
      117,
      22
     ],
     "id": "obj-78"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s10_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1300,
      1260,
      131,
      22
     ],
     "id": "obj-79"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s11_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      292,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      292,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S11 On",
       "parameter_shortname": "S11 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-80"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s11_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      288,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      288,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S11 Vel",
       "parameter_shortname": "Vel11",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-81"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s11_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      288,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      288,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S11 Pitch",
       "parameter_shortname": "Pit11",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-82"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s11_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1440,
      1200,
      110,
      22
     ],
     "id": "obj-83"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s11_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1440,
      1230,
      117,
      22
     ],
     "id": "obj-84"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s11_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1440,
      1260,
      131,
      22
     ],
     "id": "obj-85"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s12_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      316,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      316,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S12 On",
       "parameter_shortname": "S12 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-86"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s12_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      312,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      312,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S12 Vel",
       "parameter_shortname": "Vel12",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-87"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s12_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      312,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      312,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S12 Pitch",
       "parameter_shortname": "Pit12",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-88"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s12_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1580,
      1200,
      110,
      22
     ],
     "id": "obj-89"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s12_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1580,
      1230,
      117,
      22
     ],
     "id": "obj-90"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s12_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1580,
      1260,
      131,
      22
     ],
     "id": "obj-91"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s13_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      340,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      340,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S13 On",
       "parameter_shortname": "S13 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-92"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s13_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      336,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      336,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S13 Vel",
       "parameter_shortname": "Vel13",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-93"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s13_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      336,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      336,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S13 Pitch",
       "parameter_shortname": "Pit13",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-94"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s13_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1720,
      1200,
      110,
      22
     ],
     "id": "obj-95"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s13_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1720,
      1230,
      117,
      22
     ],
     "id": "obj-96"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s13_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1720,
      1260,
      131,
      22
     ],
     "id": "obj-97"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s14_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      364,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      364,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S14 On",
       "parameter_shortname": "S14 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-98"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s14_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      360,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      360,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S14 Vel",
       "parameter_shortname": "Vel14",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-99"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s14_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      360,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      360,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S14 Pitch",
       "parameter_shortname": "Pit14",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-100"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s14_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1860,
      1200,
      110,
      22
     ],
     "id": "obj-101"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s14_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1860,
      1230,
      117,
      22
     ],
     "id": "obj-102"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s14_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      1860,
      1260,
      131,
      22
     ],
     "id": "obj-103"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s15_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      388,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      388,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S15 On",
       "parameter_shortname": "S15 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-104"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s15_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      384,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      384,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S15 Vel",
       "parameter_shortname": "Vel15",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-105"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s15_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      384,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      384,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S15 Pitch",
       "parameter_shortname": "Pit15",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-106"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s15_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      2000,
      1200,
      110,
      22
     ],
     "id": "obj-107"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s15_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      2000,
      1230,
      117,
      22
     ],
     "id": "obj-108"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s15_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      2000,
      1260,
      131,
      22
     ],
     "id": "obj-109"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "s16_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      412,
      420,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      412,
      20,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S16 On",
       "parameter_shortname": "S16 On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-110"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s16_vel",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      408,
      440,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      408,
      40,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S16 Vel",
       "parameter_shortname": "Vel16",
       "parameter_type": 0,
       "parameter_initial": [
        1.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-111"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "s16_pitch",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      408,
      472,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      408,
      72,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "S16 Pitch",
       "parameter_shortname": "Pit16",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": -24.0,
       "parameter_mmax": 24.0,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-112"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s16_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      2140,
      1200,
      110,
      22
     ],
     "id": "obj-113"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s16_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      2140,
      1230,
      117,
      22
     ],
     "id": "obj-114"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend s16_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      2140,
      1260,
      131,
      22
     ],
     "id": "obj-115"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "SEQ",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      48,
      506,
      30,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      48,
      106,
      30,
      14
     ],
     "id": "obj-116"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "seq_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      48,
      522,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      48,
      122,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Seq On",
       "parameter_shortname": "Seq On",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-117"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend seq_on",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      40,
      1320,
      110,
      22
     ],
     "id": "obj-118"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "CLOCK",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      72,
      506,
      60,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      72,
      106,
      60,
      14
     ],
     "id": "obj-119"
    }
   },
   {
    "box": {
     "maxclass": "live.tab",
     "varname": "clock_mode",
     "numinlets": 1,
     "numoutlets": 3,
     "outlettype": [
      "",
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      72,
      522,
      96,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      72,
      122,
      96,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Clock",
       "parameter_shortname": "Clock",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "Host",
        "Ext",
        "Int"
       ],
       "parameter_mmax": 2
      }
     },
     "num_lines_presentation": 1,
     "num_lines_patching": 1,
     "id": "obj-120"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend clock_mode",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      200,
      1320,
      138,
      22
     ],
     "id": "obj-121"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "DIV",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      176,
      506,
      40,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      176,
      106,
      40,
      14
     ],
     "id": "obj-122"
    }
   },
   {
    "box": {
     "maxclass": "live.menu",
     "varname": "clock_div",
     "numinlets": 1,
     "numoutlets": 3,
     "outlettype": [
      "",
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      176,
      522,
      52,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      176,
      122,
      52,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Division",
       "parameter_shortname": "Division",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "1/8",
        "1/16",
        "1/32",
        "1/8T",
        "1/16T"
       ],
       "parameter_mmax": 4
      }
     },
     "id": "obj-123"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend clock_div",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      360,
      1320,
      131,
      22
     ],
     "id": "obj-124"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "seq_len",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      240,
      504,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      240,
      104,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Length",
       "parameter_shortname": "Length",
       "parameter_type": 1,
       "parameter_initial": [
        16
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 1,
       "parameter_mmax": 16,
       "parameter_unitstyle": 0
      }
     },
     "id": "obj-125"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend seq_len",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      520,
      1320,
      117,
      22
     ],
     "id": "obj-126"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "bpm",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      292,
      504,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      292,
      104,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Int BPM",
       "parameter_shortname": "BPM",
       "parameter_type": 0,
       "parameter_initial": [
        130.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 40.0,
       "parameter_mmax": 300.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-127"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend bpm",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      680,
      1320,
      89,
      22
     ],
     "id": "obj-128"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "RESET",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      344,
      506,
      40,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      344,
      106,
      40,
      14
     ],
     "id": "obj-129"
    }
   },
   {
    "box": {
     "maxclass": "live.button",
     "varname": "reset",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      348,
      522,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      348,
      122,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Reset",
       "parameter_shortname": "Reset",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-130"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "counter 0 0 1",
     "numinlets": 3,
     "numoutlets": 4,
     "outlettype": [
      "",
      "",
      "",
      ""
     ],
     "patching_rect": [
      840,
      1320,
      103,
      22
     ],
     "id": "obj-131"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend reset_id",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      840,
      1345,
      124,
      22
     ],
     "id": "obj-132"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "js seq_random.js",
     "numinlets": 1,
     "numoutlets": 0,
     "outlettype": [],
     "patching_rect": [
      40,
      1400,
      124,
      22
     ],
     "id": "obj-133"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "RANDOM",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      444,
      402,
      60,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      444,
      2,
      60,
      14
     ],
     "id": "obj-134"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "Rnd  Range  Live",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      440,
      506,
      120,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      440,
      106,
      120,
      14
     ],
     "id": "obj-135"
    }
   },
   {
    "box": {
     "maxclass": "live.button",
     "varname": "rand_steps",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      444,
      422,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      444,
      22,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Rand Steps",
       "parameter_shortname": "Rand Steps",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-136"
    }
   },
   {
    "box": {
     "maxclass": "message",
     "text": "rand_steps",
     "numinlets": 2,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      200,
      1400,
      82,
      22
     ],
     "id": "obj-137"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "density",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      468,
      420,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      468,
      20,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Density",
       "parameter_shortname": "Dens",
       "parameter_type": 0,
       "parameter_initial": [
        0.6
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-138"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend density",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      200,
      1440,
      117,
      22
     ],
     "id": "obj-139"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "live_steps",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      500,
      422,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      500,
      22,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Live Steps",
       "parameter_shortname": "Live Steps",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-140"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend live_steps",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      200,
      1470,
      138,
      22
     ],
     "id": "obj-141"
    }
   },
   {
    "box": {
     "maxclass": "live.button",
     "varname": "rand_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      444,
      444,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      444,
      44,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Rand Vel",
       "parameter_shortname": "Rand Vel",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-142"
    }
   },
   {
    "box": {
     "maxclass": "message",
     "text": "rand_vel",
     "numinlets": 2,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      340,
      1400,
      68,
      22
     ],
     "id": "obj-143"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "vel_range",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      468,
      442,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      468,
      42,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Vel Range",
       "parameter_shortname": "VRng",
       "parameter_type": 0,
       "parameter_initial": [
        0.5
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-144"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend vel_range",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      340,
      1440,
      131,
      22
     ],
     "id": "obj-145"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "live_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      500,
      444,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      500,
      44,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Live Vel",
       "parameter_shortname": "Live Vel",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-146"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend live_vel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      340,
      1470,
      124,
      22
     ],
     "id": "obj-147"
    }
   },
   {
    "box": {
     "maxclass": "live.button",
     "varname": "rand_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      444,
      476,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      444,
      76,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Rand Pitch",
       "parameter_shortname": "Rand Pitch",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-148"
    }
   },
   {
    "box": {
     "maxclass": "message",
     "text": "rand_pitch",
     "numinlets": 2,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      480,
      1400,
      82,
      22
     ],
     "id": "obj-149"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "pitch_range",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      468,
      474,
      24,
      26
     ],
     "presentation": 1,
     "presentation_rect": [
      468,
      74,
      24,
      26
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Pitch Range",
       "parameter_shortname": "PRng",
       "parameter_type": 1,
       "parameter_initial": [
        7
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0,
       "parameter_mmax": 24,
       "parameter_unitstyle": 7
      }
     },
     "showname": 0,
     "shownumber": 0,
     "id": "obj-150"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend pitch_range",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      480,
      1440,
      145,
      22
     ],
     "id": "obj-151"
    }
   },
   {
    "box": {
     "maxclass": "live.toggle",
     "varname": "live_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      500,
      476,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      500,
      76,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Live Pitch",
       "parameter_shortname": "Live Pitch",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-152"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend live_pitch",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      480,
      1470,
      138,
      22
     ],
     "id": "obj-153"
    }
   },
   {
    "box": {
     "maxclass": "live.button",
     "varname": "clear",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "parameter_enable": 1,
     "patching_rect": [
      444,
      522,
      16,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      444,
      122,
      16,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Clear Pattern",
       "parameter_shortname": "Clear Pattern",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "off",
        "on"
       ],
       "parameter_mmax": 1
      }
     },
     "id": "obj-154"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "Clear",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      462,
      522,
      40,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      462,
      122,
      40,
      14
     ],
     "id": "obj-155"
    }
   },
   {
    "box": {
     "maxclass": "message",
     "text": "clear_pattern",
     "numinlets": 2,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      620,
      1400,
      103,
      22
     ],
     "id": "obj-156"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "VOICE",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      580,
      402,
      60,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      580,
      2,
      60,
      14
     ],
     "id": "obj-157"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "tune",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      580,
      414,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      580,
      14,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Tune",
       "parameter_shortname": "Tune",
       "parameter_type": 0,
       "parameter_initial": [
        56.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 24.0,
       "parameter_mmax": 96.0,
       "parameter_unitstyle": 8
      }
     },
     "id": "obj-158"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend tune",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      40,
      1520,
      96,
      22
     ],
     "id": "obj-159"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "morph",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      636,
      414,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      636,
      14,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Morph",
       "parameter_shortname": "Morph",
       "parameter_type": 0,
       "parameter_initial": [
        0.0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-160"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend morph",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      180,
      1520,
      103,
      22
     ],
     "id": "obj-161"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "inharm",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      692,
      414,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      692,
      14,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Inharm",
       "parameter_shortname": "Inharm",
       "parameter_type": 0,
       "parameter_initial": [
        0.5
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-162"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend inharm",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      320,
      1520,
      110,
      22
     ],
     "id": "obj-163"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "decay",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      748,
      414,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      748,
      14,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Decay",
       "parameter_shortname": "Decay",
       "parameter_type": 0,
       "parameter_initial": [
        0.3
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-164"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend decay",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      460,
      1520,
      103,
      22
     ],
     "id": "obj-165"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "damp",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      804,
      414,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      804,
      14,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Damp",
       "parameter_shortname": "Damp",
       "parameter_type": 0,
       "parameter_initial": [
        0.5
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-166"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend damp",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      600,
      1520,
      96,
      22
     ],
     "id": "obj-167"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "bright",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      860,
      414,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      860,
      14,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Bright",
       "parameter_shortname": "Bright",
       "parameter_type": 0,
       "parameter_initial": [
        0.6
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-168"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend bright",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      740,
      1520,
      110,
      22
     ],
     "id": "obj-169"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "drive",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      580,
      464,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      580,
      64,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Drive",
       "parameter_shortname": "Drive",
       "parameter_type": 0,
       "parameter_initial": [
        0.2
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-170"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend drive",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      110,
      1550,
      103,
      22
     ],
     "id": "obj-171"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "noise_mix",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      636,
      464,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      636,
      64,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Noise",
       "parameter_shortname": "Noise",
       "parameter_type": 0,
       "parameter_initial": [
        0.05
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-172"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend noise_mix",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      250,
      1550,
      131,
      22
     ],
     "id": "obj-173"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "accent",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      692,
      464,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      692,
      64,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Accent",
       "parameter_shortname": "Accent",
       "parameter_type": 0,
       "parameter_initial": [
        0.5
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-174"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend accent",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      390,
      1550,
      110,
      22
     ],
     "id": "obj-175"
    }
   },
   {
    "box": {
     "maxclass": "live.dial",
     "varname": "level",
     "numinlets": 1,
     "numoutlets": 2,
     "outlettype": [
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      748,
      464,
      44,
      48
     ],
     "presentation": 1,
     "presentation_rect": [
      748,
      64,
      44,
      48
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Level",
       "parameter_shortname": "Level",
       "parameter_type": 0,
       "parameter_initial": [
        0.8
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_mmin": 0.0,
       "parameter_mmax": 1.0,
       "parameter_unitstyle": 1
      }
     },
     "id": "obj-176"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend level",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      530,
      1550,
      103,
      22
     ],
     "id": "obj-177"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "WAVE",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      806,
      464,
      60,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      806,
      64,
      60,
      14
     ],
     "id": "obj-178"
    }
   },
   {
    "box": {
     "maxclass": "live.tab",
     "varname": "waveform",
     "numinlets": 1,
     "numoutlets": 3,
     "outlettype": [
      "",
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      806,
      480,
      112,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      806,
      80,
      112,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Wave",
       "parameter_shortname": "Wave",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "Sin",
        "Sqr",
        "Saw",
        "Tri"
       ],
       "parameter_mmax": 3
      }
     },
     "num_lines_presentation": 1,
     "num_lines_patching": 1,
     "id": "obj-179"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend waveform",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      40,
      1600,
      124,
      22
     ],
     "id": "obj-180"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "PITCH MODE",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      580,
      516,
      80,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      580,
      116,
      80,
      14
     ],
     "id": "obj-181"
    }
   },
   {
    "box": {
     "maxclass": "live.tab",
     "varname": "qmode",
     "numinlets": 1,
     "numoutlets": 3,
     "outlettype": [
      "",
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      580,
      532,
      84,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      580,
      132,
      84,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Pitch Mode",
       "parameter_shortname": "Pitch Mode",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "Loose",
        "Scale"
       ],
       "parameter_mmax": 1
      }
     },
     "num_lines_presentation": 1,
     "num_lines_patching": 1,
     "id": "obj-182"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend qmode",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      200,
      1600,
      103,
      22
     ],
     "id": "obj-183"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "SCALE",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      672,
      516,
      60,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      672,
      116,
      60,
      14
     ],
     "id": "obj-184"
    }
   },
   {
    "box": {
     "maxclass": "live.menu",
     "varname": "scale_sel",
     "numinlets": 1,
     "numoutlets": 3,
     "outlettype": [
      "",
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      672,
      532,
      120,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      672,
      132,
      120,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Scale",
       "parameter_shortname": "Scale",
       "parameter_type": 2,
       "parameter_initial": [
        1
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "Chromatic",
        "Minor",
        "Phrygian",
        "Harmonic Minor",
        "Minor Pentatonic",
        "Dorian",
        "Phrygian Dominant",
        "Hirajoshi"
       ],
       "parameter_mmax": 7
      }
     },
     "id": "obj-185"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend scale_sel",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      360,
      1600,
      131,
      22
     ],
     "id": "obj-186"
    }
   },
   {
    "box": {
     "maxclass": "comment",
     "text": "ROOT",
     "numinlets": 1,
     "numoutlets": 0,
     "fontsize": 9.5,
     "patching_rect": [
      800,
      516,
      40,
      14
     ],
     "presentation": 1,
     "presentation_rect": [
      800,
      116,
      40,
      14
     ],
     "id": "obj-187"
    }
   },
   {
    "box": {
     "maxclass": "live.menu",
     "varname": "root",
     "numinlets": 1,
     "numoutlets": 3,
     "outlettype": [
      "",
      "",
      "float"
     ],
     "parameter_enable": 1,
     "patching_rect": [
      800,
      532,
      52,
      16
     ],
     "presentation": 1,
     "presentation_rect": [
      800,
      132,
      52,
      16
     ],
     "saved_attribute_attributes": {
      "valueof": {
       "parameter_longname": "Root",
       "parameter_shortname": "Root",
       "parameter_type": 2,
       "parameter_initial": [
        0
       ],
       "parameter_initial_enable": 1,
       "parameter_invisible": 0,
       "parameter_enum": [
        "C",
        "C#",
        "D",
        "D#",
        "E",
        "F",
        "F#",
        "G",
        "G#",
        "A",
        "A#",
        "B"
       ],
       "parameter_mmax": 11
      }
     },
     "id": "obj-188"
    }
   },
   {
    "box": {
     "maxclass": "newobj",
     "text": "prepend root",
     "numinlets": 1,
     "numoutlets": 1,
     "outlettype": [
      ""
     ],
     "patching_rect": [
      520,
      1600,
      96,
      22
     ],
     "id": "obj-189"
    }
   }
  ],
  "lines": [
   {
    "patchline": {
     "source": [
      "obj-2",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-1",
      0
     ],
     "destination": [
      "obj-3",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-1",
      0
     ],
     "destination": [
      "obj-3",
      1
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-3",
      0
     ],
     "destination": [
      "obj-4",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-3",
      1
     ],
     "destination": [
      "obj-4",
      1
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-1",
      2
     ],
     "destination": [
      "obj-6",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-6",
      0
     ],
     "destination": [
      "obj-7",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-7",
      0
     ],
     "destination": [
      "obj-8",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-8",
      0
     ],
     "destination": [
      "obj-5",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-9",
      0
     ],
     "destination": [
      "obj-10",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-10",
      0
     ],
     "destination": [
      "obj-11",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-11",
      1
     ],
     "destination": [
      "obj-12",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-11",
      0
     ],
     "destination": [
      "obj-13",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-12",
      0
     ],
     "destination": [
      "obj-14",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-14",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-12",
      1
     ],
     "destination": [
      "obj-15",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-15",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-13",
      0
     ],
     "destination": [
      "obj-16",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-16",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-20",
      0
     ],
     "destination": [
      "obj-23",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-23",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-21",
      0
     ],
     "destination": [
      "obj-24",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-24",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-22",
      0
     ],
     "destination": [
      "obj-25",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-25",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-26",
      0
     ],
     "destination": [
      "obj-29",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-29",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-27",
      0
     ],
     "destination": [
      "obj-30",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-30",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-28",
      0
     ],
     "destination": [
      "obj-31",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-31",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-32",
      0
     ],
     "destination": [
      "obj-35",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-35",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-33",
      0
     ],
     "destination": [
      "obj-36",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-36",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-34",
      0
     ],
     "destination": [
      "obj-37",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-37",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-38",
      0
     ],
     "destination": [
      "obj-41",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-41",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-39",
      0
     ],
     "destination": [
      "obj-42",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-42",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-40",
      0
     ],
     "destination": [
      "obj-43",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-43",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-44",
      0
     ],
     "destination": [
      "obj-47",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-47",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-45",
      0
     ],
     "destination": [
      "obj-48",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-48",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-46",
      0
     ],
     "destination": [
      "obj-49",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-49",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-50",
      0
     ],
     "destination": [
      "obj-53",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-53",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-51",
      0
     ],
     "destination": [
      "obj-54",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-54",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-52",
      0
     ],
     "destination": [
      "obj-55",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-55",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-56",
      0
     ],
     "destination": [
      "obj-59",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-59",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-57",
      0
     ],
     "destination": [
      "obj-60",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-60",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-58",
      0
     ],
     "destination": [
      "obj-61",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-61",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-62",
      0
     ],
     "destination": [
      "obj-65",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-65",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-63",
      0
     ],
     "destination": [
      "obj-66",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-66",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-64",
      0
     ],
     "destination": [
      "obj-67",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-67",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-68",
      0
     ],
     "destination": [
      "obj-71",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-71",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-69",
      0
     ],
     "destination": [
      "obj-72",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-72",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-70",
      0
     ],
     "destination": [
      "obj-73",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-73",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-74",
      0
     ],
     "destination": [
      "obj-77",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-77",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-75",
      0
     ],
     "destination": [
      "obj-78",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-78",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-76",
      0
     ],
     "destination": [
      "obj-79",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-79",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-80",
      0
     ],
     "destination": [
      "obj-83",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-83",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-81",
      0
     ],
     "destination": [
      "obj-84",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-84",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-82",
      0
     ],
     "destination": [
      "obj-85",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-85",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-86",
      0
     ],
     "destination": [
      "obj-89",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-89",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-87",
      0
     ],
     "destination": [
      "obj-90",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-90",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-88",
      0
     ],
     "destination": [
      "obj-91",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-91",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-92",
      0
     ],
     "destination": [
      "obj-95",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-95",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-93",
      0
     ],
     "destination": [
      "obj-96",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-96",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-94",
      0
     ],
     "destination": [
      "obj-97",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-97",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-98",
      0
     ],
     "destination": [
      "obj-101",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-101",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-99",
      0
     ],
     "destination": [
      "obj-102",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-102",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-100",
      0
     ],
     "destination": [
      "obj-103",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-103",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-104",
      0
     ],
     "destination": [
      "obj-107",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-107",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-105",
      0
     ],
     "destination": [
      "obj-108",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-108",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-106",
      0
     ],
     "destination": [
      "obj-109",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-109",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-110",
      0
     ],
     "destination": [
      "obj-113",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-113",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-111",
      0
     ],
     "destination": [
      "obj-114",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-114",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-112",
      0
     ],
     "destination": [
      "obj-115",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-115",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-117",
      0
     ],
     "destination": [
      "obj-118",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-118",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-120",
      0
     ],
     "destination": [
      "obj-121",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-121",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-123",
      0
     ],
     "destination": [
      "obj-124",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-124",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-125",
      0
     ],
     "destination": [
      "obj-126",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-126",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-127",
      0
     ],
     "destination": [
      "obj-128",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-128",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-130",
      0
     ],
     "destination": [
      "obj-131",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-131",
      0
     ],
     "destination": [
      "obj-132",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-132",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-136",
      0
     ],
     "destination": [
      "obj-137",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-137",
      0
     ],
     "destination": [
      "obj-133",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-138",
      0
     ],
     "destination": [
      "obj-139",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-139",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-140",
      0
     ],
     "destination": [
      "obj-141",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-141",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-142",
      0
     ],
     "destination": [
      "obj-143",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-143",
      0
     ],
     "destination": [
      "obj-133",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-144",
      0
     ],
     "destination": [
      "obj-145",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-145",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-146",
      0
     ],
     "destination": [
      "obj-147",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-147",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-148",
      0
     ],
     "destination": [
      "obj-149",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-149",
      0
     ],
     "destination": [
      "obj-133",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-150",
      0
     ],
     "destination": [
      "obj-151",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-151",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-152",
      0
     ],
     "destination": [
      "obj-153",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-153",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-154",
      0
     ],
     "destination": [
      "obj-156",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-156",
      0
     ],
     "destination": [
      "obj-133",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-158",
      0
     ],
     "destination": [
      "obj-159",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-159",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-160",
      0
     ],
     "destination": [
      "obj-161",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-161",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-162",
      0
     ],
     "destination": [
      "obj-163",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-163",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-164",
      0
     ],
     "destination": [
      "obj-165",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-165",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-166",
      0
     ],
     "destination": [
      "obj-167",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-167",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-168",
      0
     ],
     "destination": [
      "obj-169",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-169",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-170",
      0
     ],
     "destination": [
      "obj-171",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-171",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-172",
      0
     ],
     "destination": [
      "obj-173",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-173",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-174",
      0
     ],
     "destination": [
      "obj-175",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-175",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-176",
      0
     ],
     "destination": [
      "obj-177",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-177",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-179",
      0
     ],
     "destination": [
      "obj-180",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-180",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-182",
      0
     ],
     "destination": [
      "obj-183",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-183",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-185",
      0
     ],
     "destination": [
      "obj-186",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-186",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-188",
      0
     ],
     "destination": [
      "obj-189",
      0
     ]
    }
   },
   {
    "patchline": {
     "source": [
      "obj-189",
      0
     ],
     "destination": [
      "obj-1",
      0
     ]
    }
   }
  ],
  "dependency_cache": [
   {
    "name": "seq_random.js",
    "bootpath": ".",
    "type": "TEXT",
    "implicit": 1
   }
  ]
 }
}