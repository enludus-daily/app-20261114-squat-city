# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.009（予定の枠。2026-11-14 時点で slots.json は requested。App Store Connect に App がまだない） |
| アプリ名 | しゃがんで建てる：スクワットで街づくり / Squat City: Build by Squatting |
| サポート URL | https://github.com/enludus-daily/app-20261114-squat-city/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261114-squat-city/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」（暴力・性的・ギャンブル・Web 閲覧・生成 AI・ユーザー同士の交流なし）→ 4+ の見込み |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：単純なカウンター・タイマーではない。回数と下ろす速さがブロックの出来になり、1 日 1 棟・月の通りとして積み上がる街づくりの仕組み、日替わりの注文 60 本、街に置かれる物 40 種、やり方 6 種と建物 5 種を持つ
- 既存のアプリとの意味のある違い：加速度で数えるアプリ（Squatstar など）や 30 日のチャレンジ（30 Day Squat Challenge など）は数と表だけ。ここは回数と下ろす速さが建物になり、街が育つ
- 長く使える価値（4.2）：月ごとのスカイラインが残り、通算のブロックで街に物が増える（8,000 ブロックまで 40 段階）
- 他社の名前・商標・見た目を使っていないか：使っていない。建物・街の絵はすべて自作の Canvas
- 健康の主張：医療の効果はうたわない。「痛みがあるときは休んで」を設定と説明に書いた
- Apple Intelligence：使わない

## 収益の道筋

- 買い切りの Pro ¥480（`docs/products.json`）。理由と比べたアプリ・勝算の表は README の「課金」
- 枠ができたら：asc products → testflight → asc metadata の順に動かす

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、街の記録は端末の Application Support の JSON、設定は UserDefaults だけ。動きのデータは数えたらすぐ捨て、保存も送信もしない）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）。CoreMotion の deviceMotion は required reason API ではなく、許可の確認も要らない

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ。名前の `_ja` は日本語の画面）。審査用の課金の画像は `docs/iap/paywall.png`（paywall_ja を使う）。

## 本人がすること

- [ ] 枠 009 の App を App Store Connect に足して、slots.json を free にする
- [ ] 署名のエラー（daily-ideas #22 の①）を直す
- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（実機で胸・ポケットの数え方、購入と復元）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
