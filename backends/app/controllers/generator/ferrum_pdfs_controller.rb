class Generator::FerrumPdfsController < ApplicationController
  def show
    # chromiumのエンジン(印刷機能)を使用して、PDFを作成する
    # htmlでレイアウトする
    # 印刷時点では、htmlのどの要素がどのページにレンダリングされるかはわからない
    # そのため、一度書き出したPDFを読み取り用のモジュールで解析して再レンダリングする必要がある
    # レイアウトコストは低いが、レイアウトの柔軟性は低い
    FerrumPdf.configure do |config|
      config.window_size = [ 1920, 1080 ]

      config.process_timeout = 60 # defaults to 10
      config.browser_path = "/usr/bin/chromium"
      config.headless = true

      # For use with Docker, but ensure you trust any sites visited
      config.browser_options = {
        "no-sandbox" => true
      }

      config.pdf_options.margin_top = 0.8
      config.pdf_options.margin_bottom = 0.8
      # config.pdf_options.margin_left = 0.2
      # config.pdf_options.margin_right = 0.2
    end

    respond_to do |format|
      format.html
      # format.pdf { render ferrum_pdf: {}, disposition: :inline, type: "application/pdf", filename: "example.pdf" }
      format.pdf do
        # 1. HTML を文字列として生成（UTF-8）
        html = render_to_string(
          action: :show,     # invoices/show.html.erb を使う想定
          # layout: "pdf",     # さっき作った layout
          layout: false,
          formats: [ :html ]   # 明示的に HTML としてレンダリング
        )

        # 念のためエンコーディングを揃える（ほぼ不要だけど保険）
        html = html.encode("UTF-8")

        info = nil

        # 2. FerrumPdf で HTML → PDF
        pdf = FerrumPdf.render_pdf(
          html: html,
          # 相対パスな画像・CSS がある場合に備えて display_url を渡すと吉
          display_url: generator_ferrum_pdf_url(params[:id], format: :html)
        ) do |browser, page|
          info = page.evaluate <<~JS
            (function() {
              const pageHeight = window.innerHeight;
              const content = document.querySelector('.content') || document.body;
              const rect = content.getBoundingClientRect();
              const contentHeight = rect.height;

              const pageCount = Math.ceil(contentHeight / pageHeight);
              const lastPageContentHeightRaw = contentHeight - pageHeight * (pageCount - 1);
              const lastPageContentHeight =
                lastPageContentHeightRaw === 0 ? pageHeight : lastPageContentHeightRaw;

              return {
                pageHeight: pageHeight,
                contentHeight: contentHeight,
                pageCount: pageCount,
                lastPageContentHeight: lastPageContentHeight
              };
            })();
          JS
        end

        # 1ページあたりの高さ（px）を決め打ち（実際は実測して調整）
        page_height = info["pageHeight"].to_f
        last_page_content_height = info["lastPageContentHeight"].to_f

        pp page_height
        pp last_page_content_height

        # 「最後のページの高さ」が例えば 1 行 ≒ 24px 未満なら「1行ポツン」とみなす
        if last_page_content_height < 40 # ここは調整ポイント
          FerrumPdf.configure do |config|
            config.window_size = [ 1920, 1080 ]

            config.process_timeout = 60 # defaults to 10
            config.browser_path = "/usr/bin/chromium"
            config.headless = true

            # For use with Docker, but ensure you trust any sites visited
            config.browser_options = {
              "no-sandbox" => true
            }

            config.pdf_options.margin_top = 0
            config.pdf_options.margin_bottom = 0
            # config.pdf_options.margin_left = 0.2
            # config.pdf_options.margin_right = 0.2
          end
          pp "!!!"
          pdf = FerrumPdf.render_pdf(html: html)
        else
          # そのまま PDF を作る
          pp "@@@"
          pdf = FerrumPdf.render_pdf(html: html)
        end

        # 3. PDF を返す
        send_data pdf,
          type: "application/pdf",
          disposition: :inline,
          filename: "invoice-#{params[:id]}.pdf"
      end
    end
  end
end
