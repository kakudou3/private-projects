class Generator::HexaPdfsController < ApplicationController
  def show
    # 低レイヤーなPDFレンダリングエンジン
    # 座標を指定して、組版をレイアウトする
    # 要素の高さとPDFの高さを計算していくことで、ページのマージンと要素を動的に調整することができる
    # レイアウトコストは高いが、レイアウトの柔軟性は高い
    doc = HexaPDF::Document.new
    page = doc.pages.add
    pp page.box.value
    font_path = Rails.root.join("app", "assets", "fonts", "NotoSansJP-Regular.ttf")
    font = doc.fonts.add(font_path.to_s)
    canvas = page.canvas
    canvas.font(font, size: 100)

    frag = doc.layout.text_fragments("サンプルです。", font:)
    layouter = HexaPDF::Layout::TextLayouter.new
    result = layouter.fit(frag, 60, 400)
    result.draw(canvas, 20, 400)

    # canvas.text("サンプルです。", at: [ 20, 400 ])
    io = StringIO.new("".b)
    doc.write(io, optimize: true)

    send_data(
      io.string,
      disposition: :inline, # :inlineにすると、ブラウザでプレビューされる
      filename: "new-filename.pdf",
      type: "application/pdf"
    )
  end
end
