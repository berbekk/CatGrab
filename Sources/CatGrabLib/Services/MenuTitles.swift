import Foundation

/// Заголовки стандартных пунктов главного меню macOS (App, Edit, Window).
/// Эти строки обычно на уровне системы не локализуются за нас, когда приложение собрано без Xcode-локализации,
/// поэтому держим их отдельно от основной `L10nKey`-таблицы.
enum MenuTitles {
    static func about(appName: String, language: AppLanguage) -> String {
        switch language {
        case .russian:      return "О программе \(appName)"
        case .chinese:      return "关于 \(appName)"
        case .japanese:     return "\(appName) について"
        case .german:       return "Über \(appName)"
        case .french:       return "À propos de \(appName)"
        case .spanish:      return "Acerca de \(appName)"
        case .portuguese:   return "Sobre o \(appName)"
        case .indonesian:   return "Tentang \(appName)"
        case .arabic:       return "حول \(appName)"
        case .hindi:        return "\(appName) के बारे में"
        case .bengali:      return "\(appName) সম্পর্কে"
        case .urdu:         return "\(appName) کے بارے میں"
        case .english:      return "About \(appName)"
        }
    }

    static func hide(appName: String, language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Скрыть \(appName)"
        case .chinese:      return "隐藏 \(appName)"
        case .japanese:     return "\(appName) を隠す"
        case .german:       return "\(appName) ausblenden"
        case .french:       return "Masquer \(appName)"
        case .spanish:      return "Ocultar \(appName)"
        case .portuguese:   return "Ocultar \(appName)"
        case .indonesian:   return "Sembunyikan \(appName)"
        case .arabic:       return "إخفاء \(appName)"
        case .hindi:        return "\(appName) छिपाएँ"
        case .bengali:      return "\(appName) লুকান"
        case .urdu:         return "\(appName) چھپائیں"
        case .english:      return "Hide \(appName)"
        }
    }

    static func hideOthers(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Скрыть остальные"
        case .chinese:      return "隐藏其他"
        case .japanese:     return "ほかを隠す"
        case .german:       return "Andere ausblenden"
        case .french:       return "Masquer les autres"
        case .spanish:      return "Ocultar otras"
        case .portuguese:   return "Ocultar outros"
        case .indonesian:   return "Sembunyikan Lainnya"
        case .arabic:       return "إخفاء الأخرى"
        case .hindi:        return "अन्य छिपाएँ"
        case .bengali:      return "অন্যান্য লুকান"
        case .urdu:         return "دوسرے چھپائیں"
        case .english:      return "Hide Others"
        }
    }

    static func showAll(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Показать все"
        case .chinese:      return "全部显示"
        case .japanese:     return "すべてを表示"
        case .german:       return "Alle einblenden"
        case .french:       return "Tout afficher"
        case .spanish:      return "Mostrar todo"
        case .portuguese:   return "Mostrar tudo"
        case .indonesian:   return "Tampilkan Semua"
        case .arabic:       return "إظهار الكل"
        case .hindi:        return "सब दिखाएँ"
        case .bengali:      return "সব দেখান"
        case .urdu:         return "سب دکھائیں"
        case .english:      return "Show All"
        }
    }

    static func services(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Службы"
        case .chinese:      return "服务"
        case .japanese:     return "サービス"
        case .german:       return "Dienste"
        case .french:       return "Services"
        case .spanish:      return "Servicios"
        case .portuguese:   return "Serviços"
        case .indonesian:   return "Layanan"
        case .arabic:       return "الخدمات"
        case .hindi:        return "सेवाएँ"
        case .bengali:      return "পরিষেবা"
        case .urdu:         return "خدمات"
        case .english:      return "Services"
        }
    }

    static func quit(appName: String, language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Завершить \(appName)"
        case .chinese:      return "退出 \(appName)"
        case .japanese:     return "\(appName) を終了"
        case .german:       return "\(appName) beenden"
        case .french:       return "Quitter \(appName)"
        case .spanish:      return "Salir de \(appName)"
        case .portuguese:   return "Encerrar \(appName)"
        case .indonesian:   return "Keluar \(appName)"
        case .arabic:       return "إنهاء \(appName)"
        case .hindi:        return "\(appName) बंद करें"
        case .bengali:      return "\(appName) বন্ধ করুন"
        case .urdu:         return "\(appName) بند کریں"
        case .english:      return "Quit \(appName)"
        }
    }

    static func edit(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Правка"
        case .chinese:      return "编辑"
        case .japanese:     return "編集"
        case .german:       return "Bearbeiten"
        case .french:       return "Édition"
        case .spanish:      return "Edición"
        case .portuguese:   return "Editar"
        case .indonesian:   return "Edit"
        case .arabic:       return "تحرير"
        case .hindi:        return "संपादन"
        case .bengali:      return "সম্পাদনা"
        case .urdu:         return "ترمیم"
        case .english:      return "Edit"
        }
    }

    static func undo(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Отменить"
        case .chinese:      return "撤销"
        case .japanese:     return "取り消す"
        case .german:       return "Widerrufen"
        case .french:       return "Annuler"
        case .spanish:      return "Deshacer"
        case .portuguese:   return "Desfazer"
        case .indonesian:   return "Urungkan"
        case .arabic:       return "تراجع"
        case .hindi:        return "पूर्ववत् करें"
        case .bengali:      return "পূর্বাবস্থা"
        case .urdu:         return "کالعدم کریں"
        case .english:      return "Undo"
        }
    }

    static func redo(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Повторить"
        case .chinese:      return "重做"
        case .japanese:     return "やり直す"
        case .german:       return "Wiederholen"
        case .french:       return "Rétablir"
        case .spanish:      return "Rehacer"
        case .portuguese:   return "Refazer"
        case .indonesian:   return "Ulang"
        case .arabic:       return "إعادة"
        case .hindi:        return "फिर से करें"
        case .bengali:      return "পুনরাবৃত্তি"
        case .urdu:         return "دہرائیں"
        case .english:      return "Redo"
        }
    }

    static func cut(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Вырезать"
        case .chinese:      return "剪切"
        case .japanese:     return "カット"
        case .german:       return "Ausschneiden"
        case .french:       return "Couper"
        case .spanish:      return "Cortar"
        case .portuguese:   return "Cortar"
        case .indonesian:   return "Potong"
        case .arabic:       return "قص"
        case .hindi:        return "काटें"
        case .bengali:      return "কাটুন"
        case .urdu:         return "کاٹیں"
        case .english:      return "Cut"
        }
    }

    static func copy(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Скопировать"
        case .chinese:      return "拷贝"
        case .japanese:     return "コピー"
        case .german:       return "Kopieren"
        case .french:       return "Copier"
        case .spanish:      return "Copiar"
        case .portuguese:   return "Copiar"
        case .indonesian:   return "Salin"
        case .arabic:       return "نسخ"
        case .hindi:        return "कॉपी"
        case .bengali:      return "কপি"
        case .urdu:         return "کاپی"
        case .english:      return "Copy"
        }
    }

    static func paste(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Вставить"
        case .chinese:      return "粘贴"
        case .japanese:     return "ペースト"
        case .german:       return "Einsetzen"
        case .french:       return "Coller"
        case .spanish:      return "Pegar"
        case .portuguese:   return "Colar"
        case .indonesian:   return "Tempel"
        case .arabic:       return "لصق"
        case .hindi:        return "पेस्ट"
        case .bengali:      return "পেস্ট"
        case .urdu:         return "پیسٹ"
        case .english:      return "Paste"
        }
    }

    static func delete(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Удалить"
        case .chinese:      return "删除"
        case .japanese:     return "削除"
        case .german:       return "Löschen"
        case .french:       return "Supprimer"
        case .spanish:      return "Eliminar"
        case .portuguese:   return "Apagar"
        case .indonesian:   return "Hapus"
        case .arabic:       return "حذف"
        case .hindi:        return "हटाएँ"
        case .bengali:      return "মুছুন"
        case .urdu:         return "حذف کریں"
        case .english:      return "Delete"
        }
    }

    static func selectAll(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Выбрать все"
        case .chinese:      return "全选"
        case .japanese:     return "すべてを選択"
        case .german:       return "Alle auswählen"
        case .french:       return "Tout sélectionner"
        case .spanish:      return "Seleccionar todo"
        case .portuguese:   return "Selecionar tudo"
        case .indonesian:   return "Pilih Semua"
        case .arabic:       return "تحديد الكل"
        case .hindi:        return "सभी चुनें"
        case .bengali:      return "সব নির্বাচন"
        case .urdu:         return "سب منتخب کریں"
        case .english:      return "Select All"
        }
    }

    static func window(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Окно"
        case .chinese:      return "窗口"
        case .japanese:     return "ウインドウ"
        case .german:       return "Fenster"
        case .french:       return "Fenêtre"
        case .spanish:      return "Ventana"
        case .portuguese:   return "Janela"
        case .indonesian:   return "Jendela"
        case .arabic:       return "نافذة"
        case .hindi:        return "विंडो"
        case .bengali:      return "উইন্ডো"
        case .urdu:         return "ونڈو"
        case .english:      return "Window"
        }
    }

    static func minimize(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Убрать в Dock"
        case .chinese:      return "最小化"
        case .japanese:     return "しまう"
        case .german:       return "Im Dock ablegen"
        case .french:       return "Placer dans le Dock"
        case .spanish:      return "Minimizar"
        case .portuguese:   return "Minimizar"
        case .indonesian:   return "Perkecil"
        case .arabic:       return "تصغير"
        case .hindi:        return "लघु करें"
        case .bengali:      return "ছোট করুন"
        case .urdu:         return "چھوٹا کریں"
        case .english:      return "Minimize"
        }
    }

    static func zoom(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Изменить масштаб"
        case .chinese:      return "缩放"
        case .japanese:     return "拡大/縮小"
        case .german:       return "Zoomen"
        case .french:       return "Réduire/agrandir"
        case .spanish:      return "Zoom"
        case .portuguese:   return "Zoom"
        case .indonesian:   return "Zoom"
        case .arabic:       return "تكبير"
        case .hindi:        return "ज़ूम"
        case .bengali:      return "জুম"
        case .urdu:         return "زوم"
        case .english:      return "Zoom"
        }
    }

    static func bringAllToFront(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Переместить все на передний план"
        case .chinese:      return "全部前置"
        case .japanese:     return "すべてを手前に移動"
        case .german:       return "Alle nach vorne"
        case .french:       return "Tout ramener au premier plan"
        case .spanish:      return "Traer todo al frente"
        case .portuguese:   return "Trazer tudo para a frente"
        case .indonesian:   return "Bawa Semua ke Depan"
        case .arabic:       return "إحضار الكل للأمام"
        case .hindi:        return "सब आगे लाएँ"
        case .bengali:      return "সব সামনে আনুন"
        case .urdu:         return "سب آگے لائیں"
        case .english:      return "Bring All to Front"
        }
    }

    static func closeWindow(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Закрыть окно"
        case .chinese:      return "关闭窗口"
        case .japanese:     return "ウインドウを閉じる"
        case .german:       return "Fenster schließen"
        case .french:       return "Fermer la fenêtre"
        case .spanish:      return "Cerrar ventana"
        case .portuguese:   return "Fechar janela"
        case .indonesian:   return "Tutup Jendela"
        case .arabic:       return "إغلاق النافذة"
        case .hindi:        return "विंडो बंद करें"
        case .bengali:      return "উইন্ডো বন্ধ করুন"
        case .urdu:         return "ونڈو بند کریں"
        case .english:      return "Close Window"
        }
    }

    static func toggleFullScreen(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Полноэкранный режим"
        case .chinese:      return "切换全屏幕"
        case .japanese:     return "フルスクリーンの切り替え"
        case .german:       return "Vollbild ein/aus"
        case .french:       return "Basculer en plein écran"
        case .spanish:      return "Pantalla completa"
        case .portuguese:   return "Alternar tela cheia"
        case .indonesian:   return "Alihkan Layar Penuh"
        case .arabic:       return "تبديل ملء الشاشة"
        case .hindi:        return "पूर्ण स्क्रीन टॉगल करें"
        case .bengali:      return "পূর্ণ স্ক্রিন টগল করুন"
        case .urdu:         return "فل اسکرین ٹوگل کریں"
        case .english:      return "Toggle Full Screen"
        }
    }

    static func tileLeft(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Окно слева"
        case .chinese:      return "移到左侧"
        case .japanese:     return "左に配置"
        case .german:       return "Links anordnen"
        case .french:       return "Placer à gauche"
        case .spanish:      return "Mover a la izquierda"
        case .portuguese:   return "Mover para a esquerda"
        case .indonesian:   return "Pindah ke Kiri"
        case .arabic:       return "نقل إلى اليسار"
        case .hindi:        return "बाईं ओर रखें"
        case .bengali:      return "বাঁ দিকে রাখুন"
        case .urdu:         return "بائیں طرف رکھیں"
        case .english:      return "Tile Left"
        }
    }

    static func tileRight(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Окно справа"
        case .chinese:      return "移到右侧"
        case .japanese:     return "右に配置"
        case .german:       return "Rechts anordnen"
        case .french:       return "Placer à droite"
        case .spanish:      return "Mover a la derecha"
        case .portuguese:   return "Mover para a direita"
        case .indonesian:   return "Pindah ke Kanan"
        case .arabic:       return "نقل إلى اليمين"
        case .hindi:        return "दाईं ओर रखें"
        case .bengali:      return "ডান দিকে রাখুন"
        case .urdu:         return "دائیں طرف رکھیں"
        case .english:      return "Tile Right"
        }
    }

    static func tileTop(language: AppLanguage) -> String {
        switch language {
        case .russian:     return "Окно сверху"
        case .chinese:     return "移到上方"
        case .japanese:    return "上に配置"
        case .german:      return "Oben anordnen"
        case .french:      return "Placer en haut"
        case .spanish:     return "Mover arriba"
        case .portuguese:  return "Mover para cima"
        case .indonesian:  return "Pindah ke Atas"
        case .arabic:      return "نقل إلى الأعلى"
        case .hindi:       return "ऊपर रखें"
        case .bengali:     return "ওপরে রাখুন"
        case .urdu:        return "اوپر رکھیں"
        case .english:     return "Tile Top"
        }
    }

    static func tileBottom(language: AppLanguage) -> String {
        switch language {
        case .russian:     return "Окно снизу"
        case .chinese:     return "移到下方"
        case .japanese:    return "下に配置"
        case .german:      return "Unten anordnen"
        case .french:      return "Placer en bas"
        case .spanish:     return "Mover abajo"
        case .portuguese:  return "Mover para baixo"
        case .indonesian:  return "Pindah ke Bawah"
        case .arabic:      return "نقل إلى الأسفل"
        case .hindi:       return "नीचे रखें"
        case .bengali:     return "নিচে রাখুন"
        case .urdu:        return "نیچے رکھیں"
        case .english:     return "Tile Bottom"
        }
    }

    static func centerWindow(language: AppLanguage) -> String {
        switch language {
        case .russian:     return "Окно по центру"
        case .chinese:     return "居中"
        case .japanese:    return "中央に配置"
        case .german:      return "Zentrieren"
        case .french:      return "Centrer"
        case .spanish:     return "Centrar"
        case .portuguese:  return "Centralizar"
        case .indonesian:  return "Tengahkan"
        case .arabic:      return "توسيط"
        case .hindi:       return "बीच में रखें"
        case .bengali:     return "মাঝখানে রাখুন"
        case .urdu:        return "درمیان میں رکھیں"
        case .english:     return "Center Window"
        }
    }

    static func fillScreen(language: AppLanguage) -> String {
        switch language {
        case .russian:      return "Развернуть окно"
        case .chinese:      return "填充屏幕"
        case .japanese:     return "画面いっぱいに"
        case .german:       return "Bildschirm füllen"
        case .french:       return "Remplir l’écran"
        case .spanish:      return "Llenar pantalla"
        case .portuguese:   return "Preencher a tela"
        case .indonesian:   return "Isi Layar"
        case .arabic:       return "ملء الشاشة"
        case .hindi:        return "स्क्रीन भरें"
        case .bengali:      return "স্ক্রিন ভরুন"
        case .urdu:         return "اسکرین بھریں"
        case .english:      return "Fill Screen"
        }
    }
}
