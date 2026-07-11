# Riftweld: Signalbreak

Godot 4.7製のシングルプレイヤー宇宙サルベージ×弾幕アクションです。自動射撃でAether Nodeを解体し、Shardを回収して船を恒久改修しながら、Helix Directorateが封鎖した5つの宙域を突破します。

## 収録内容

- 固有の敵挙動と弾幕を持つ5セクター、5体のガーディアン
- 7系統、合計35件の恒久アップグレード
- 10件のタスクと12件のローカル実績
- マウス、キーボード、一般的なXInput互換ゲームパッド対応
- 自動保存、音量、画面シェイク、全画面、進行リセット
- Windows、Linux、macOS、デスクトップWeb向け書き出し
- 独自の手続き型ビジュアルとゲーム内生成音響

## 操作

| 操作 | キーボード・マウス | ゲームパッド |
| --- | --- | --- |
| 移動 | マウス追従 / WASD / 矢印 | 左スティック |
| ブースト | 左クリック / Space | A / Cross |
| 一時停止 | P / Esc | Start |

攻撃は射程内で最も近いAether Nodeまたは敵へ自動で行われます。

## 開発環境

- Godot 4.7 stable
- 対象プラットフォームのGodot 4.7 export templates
- Python 3（Web版のローカル配信時のみ）

```sh
godot --path .
```

## 品質確認

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/test_content.gd
godot --headless --path . --script tests/test_release_readiness.gd
```

## リリース書き出し

```sh
mkdir -p build/windows build/linux build/macos build/web
./scripts/fetch_godot_copyright.sh .
godot --headless --path . --export-release "Windows Desktop" build/windows/Riftweld.exe
godot --headless --path . --export-release Linux build/linux/Riftweld.x86_64
godot --headless --path . --export-release macOS build/macos/Riftweld.zip
godot --headless --path . --export-release Web build/web/index.html
cp THIRD_PARTY_NOTICES.md GODOT_COPYRIGHT.txt assets/fonts/OFL.txt build/windows/
cp THIRD_PARTY_NOTICES.md GODOT_COPYRIGHT.txt assets/fonts/OFL.txt build/linux/
cp THIRD_PARTY_NOTICES.md GODOT_COPYRIGHT.txt assets/fonts/OFL.txt build/macos/
```

macOS版を一般配布する場合はApple Developer ID署名とnotarization、Windows版で警告を減らす場合はコード署名証明書が別途必要です。SteamworksのApp ID、Depot、実績API連携はストア登録後に発行される情報で設定します。ゲーム本体はSteam SDKなしでも起動・保存・全編プレイできます。

Steam提出作業は[Steam release checklist](docs/steam-release-checklist.md)、設計と受入条件は[Business requirements](docs/business-requirements.md)、第三者ライセンスは[Third-party notices](THIRD_PARTY_NOTICES.md)を参照してください。

## 知的財産とアセット

ゲーム内の名称、物語、画面、手続き型描画、効果音、BGMはこのプロジェクト用の独自実装です。外部作品のコード、画像、音声、キャラクター、ロゴは配布物へ含めません。

Noto Sans JapaneseはSIL Open Font License 1.1で利用しています。
