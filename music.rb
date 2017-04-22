::RBNACL_LIBSODIUM_GEM_LIB_PATH = "libsodium.dll"

require 'discordrb'
require 'google/apis/youtube_v3'
require 'active_support/all'

GOOGLE_API_KEY = 'GOOGLE.API.KEY'.freeze
BOT_TOKEN = 'BOT.TOKEN'.freeze
BOT_CLIENT_ID = BOT.CLIENT.ID.freeze
YOUTUBE_BASE_URL = 'https://www.youtube.com/watch?v='.freeze
MAX_RESULTS = 10.freeze

$isplaying = false
$results = Array.new(MAX_RESULTS) { Array.new(2) }

bot = Discordrb::Commands::CommandBot.new token: BOT_TOKEN, client_id: BOT_CLIENT_ID, prefix: '!'

# ボイスチャンネル 接続
bot.command(:connect, description: "Botをボイスチャンネルに繋ぐで") do |event|
    # ユーザーが現在入っているボイスチャンネルを返す
    # ユーザーがいない場合はnilを返す
    channel = event.user.voice_channel

    if channel
        # ユーザーがいる場合の処理
        bot.voice_connect(channel)
        event.respond "ボイスチャンネルに入ったで"
    else
        # ユーザーがいない場合の処理
        event.respond "ボイスチャンネルに誰もおらんで"
    end
end

# ボイスチャンネル 接続解除
bot.command(:disconnect, description: "Botをボイスチャンネルから退出させるで") do |event|
    event.voice.destroy
    event.respond "ボイスチャンネルから抜けたで"
end

# YouTube再生
bot.command(:play_id, description: "YouTubeの曲を再生するで") do |event, url|
    next "URLがないで \"!play_url URL\"" if url.empty?
    next "既に再生中やで" if $isplaying

    # youtube-dlでURLからmp3ファイルを取得
    event.respond "ダウンロード中..."
    system("youtube-dl --no-playlist -o music/s.%(ext)s -x --audio-format mp3 \"#{YOUTUBE_BASE_URL}#{url}\"")

    $isplaying = true
    event.respond "再生中やで"
    voice_bot = event.voice
    voice_bot.play_file('music/s.mp3')

    $isplaying = false
    voice_bot.stop_playing
    nil
end

# 再生(番号指定)
bot.command(:play_n, description: "検索結果を取得後に番号指定で再生できるで") do |event, n|
    next "番号指定されてないで \"!play_n 番号\"" if n.empty?
    next "検索結果取得できてないで \"!search キーワード\"" if $results.empty?

    video_id = $results[n.to_i][0]
    title = $results[n.to_i][1]

    event.respond "ダウンロード中..."
    system("youtube-dl --no-playlist -o music/s.%(ext)s -x --audio-format mp3 \"#{YOUTUBE_BASE_URL}#{video_id}\"")

    $isplaying = true
    event.respond "#{title}を再生中やで"
    voice_bot = event.voice
    voice_bot.play_file('music/s.mp3')

    $isplaying = false
    voice_bot.stop_playing
    nil
end

# 一時停止
bot.command(:pause, description: "再生中の曲を一時停止するで") do |event|
    next "再生してないで" unless $isplaying

    event.voice.pause
    event.respond "一時停止したで"
end

# 一時停止解除
bot.command(:continue, description: "一時停止を解除するで") do |event|
    next "再生してないで" unless $isplaying

    event.voice.continue
    event.respond "一時停止を解除したで"
end

# 停止
bot.command(:stop, description: "再生中の曲を停止するで") do |event|
    next "再生してないで" unless $isplaying

    $isplaying = false
    event.voice.stop_playing
    event.respond "停止したで"
end

# 検索
bot.command(:search, description: "曲を検索するで") do |event, query|
    next "検索ワードが空やで \"!search キーワード\"" if query.empty?

    # 初期化
    $results = Array.new(MAX_RESULTS) { Array.new(2) }
    output = Array.new(MAX_RESULTS + 2)

    # YouTube Data API v3で検索する
    service = Google::Apis::YoutubeV3::YouTubeService.new
    service.key = GOOGLE_API_KEY
    opt = {
        q: query,
        type: 'video',
        max_results: MAX_RESULTS,
    }
    res = service.list_searches(:snippet, opt)

    # outputの最初と最後に「```」を挿入する
    output << "```"
    res.items.each.with_index(1) do |item, i|
        id = item.id.video_id
        title = item.snippet.title
        # $resultsに「タイトル, id」を入れる
        $results[i] = [id, title]
        # outputに「番号, タイトル」を入れる
        output << "#{i}. #{title}"
    end
    output << "```"
    # outputを「\n」で区切って出力する
    event.respond output.join("\n")
end

# 終了
bot.command(:shutdown) do |event|
    bot.stop
    nil
end

bot.run
