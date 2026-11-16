// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct DisplayScalingStrings {
    enum Key: Int, CaseIterable {
        case title
        case modelScope
        case connect
        case disconnected
        case restore
        case prompt
        case restoreFailed
        case collision
        case enable
        case enableFlexible
        case directConnection
        case flexibleInstalled
        case hiDPIInstalled
        case differentIdentity
        case revertTimer
        case keep
        case revert
        case reconnect
        case overrideFailed
        case modeFailed
        case noModes
        case flexibleProfile
        case displayResolution
        case refreshRate
    }

    private let values: [Substring]

    init(_ language: AppLanguage) {
        values = Self.catalog(language).split(separator: "\n", omittingEmptySubsequences: false)
    }

    subscript(key: Key) -> String { String(values[key.rawValue]) }

    private static func catalog(_ language: AppLanguage) -> String {
        switch language {
        case .enUS:
            return """
            HiDPI Scaling
            Enable HiDPI for an external display using an administrator-approved override. macOS shares overrides with every display of the same model, including ones connected later.
            Connect an external display to configure scaling.
            Disconnected display
            Restore Previous Override
            Vorssaint needs administrator approval to update the display override.
            The disconnected display override could not be restored.
            Multiple displays share this vendor and product ID. Disconnect the others to enable or select HiDPI modes.
            Enable HiDPI
            Enable Flexible Scaling
            Connect the display directly and turn off mirroring to configure HiDPI.
            Flexible Scaling installed
            HiDPI installed
            An override is installed for this model under a different display identity. Restore it before enabling scaling here.
            The previous display mode returns in 15 seconds unless you keep the change.
            Keep Changes
            Revert
            Reconnect the display, or restart the Mac if the mode list does not update.
            The override could not be updated. Check administrator approval and whether another tool changed the file.
            macOS could not switch to that resolution.
            No HiDPI mode matches the current refresh rate. Reconnect or restart to reload modes.
            Flexible Scaling
            Resolution
            Refresh rate
            """
        case .ko:
            return """
            HiDPI 배율
            관리자 승인으로 외장 디스플레이의 HiDPI를 활성화합니다. macOS는 나중에 연결하는 디스플레이를 포함해 동일 모델 모두에 이 설정을 적용합니다.
            배율을 설정하려면 외장 디스플레이를 연결하세요.
            연결되지 않은 디스플레이
            이전 디스플레이 설정 복원
            Vorssaint가 디스플레이 설정을 변경하려면 관리자 승인이 필요합니다.
            연결되지 않은 디스플레이의 설정을 복원하지 못했습니다.
            같은 제조사 및 제품 ID를 가진 디스플레이가 여러 대 연결되어 있습니다. HiDPI를 켜거나 배율을 선택하려면 나머지를 분리하세요.
            HiDPI 켜기
            세밀한 배율 켜기
            HiDPI를 설정하려면 디스플레이를 직접 연결하고 미러링을 끄세요.
            세밀한 배율 설치됨
            HiDPI 설치됨
            이 모델에 다른 디스플레이 식별자로 설치된 설정이 있습니다. 여기서 배율을 켜기 전에 기존 설정을 복원하세요.
            변경을 유지하지 않으면 15초 후 이전 모드로 돌아갑니다.
            변경 유지
            되돌리기
            디스플레이를 다시 연결하세요. 해상도 목록이 갱신되지 않으면 Mac을 재시동하세요.
            디스플레이 설정을 변경하지 못했습니다. 관리자 승인 여부와 다른 도구가 파일을 변경했는지 확인하세요.
            macOS가 해당 해상도로 전환하지 못했습니다.
            현재 주사율과 일치하는 HiDPI 모드가 없습니다. 다시 연결하거나 재시동해 모드 목록을 갱신하세요.
            세밀한 배율
            해상도
            주사율
            """
        case .ptBR:
            return """
            Escala HiDPI
            Ative o HiDPI com autorização de administrador. O macOS aplica a configuração a todos os monitores do mesmo modelo, inclusive os conectados depois.
            Conecte um monitor externo para configurar a escala.
            Monitor desconectado
            Restaurar configuração anterior
            O Vorssaint precisa de autorização de administrador para atualizar a configuração do monitor.
            Não foi possível restaurar a configuração do monitor desconectado.
            Vários monitores têm o mesmo ID de fabricante e produto. Desconecte os demais para usar os modos HiDPI.
            Ativar HiDPI
            Ativar escala flexível
            Conecte o monitor diretamente e desative o espelhamento para configurar HiDPI.
            Escala flexível instalada
            HiDPI instalado
            Este modelo tem uma configuração instalada para outra identidade de monitor. Restaure-a antes de continuar.
            O modo anterior volta em 15 segundos se você não mantiver a alteração.
            Manter alterações
            Reverter
            Reconecte o monitor ou reinicie o Mac se a lista não for atualizada.
            Não foi possível atualizar a configuração. Verifique a autorização e se outro app alterou o arquivo.
            O macOS não conseguiu mudar a resolução.
            Nenhum modo HiDPI corresponde à taxa de atualização atual. Reconecte o monitor ou reinicie o Mac.
            Escala flexível
            Resolução
            Taxa de atualização
            """
        case .tr:
            return """
            HiDPI ölçekleme
            Yönetici onayıyla HiDPI’yi etkinleştirin. macOS bu ayarı sonradan bağlananlar dahil aynı modeldeki tüm ekranlara uygular.
            Ölçeklemeyi ayarlamak için harici bir ekran bağlayın.
            Bağlantısı kesilmiş ekran
            Önceki ayarı geri yükle
            Vorssaint ekran ayarını güncellemek için yönetici onayı istiyor.
            Bağlantısı kesilmiş ekranın ayarı geri yüklenemedi.
            Birden çok ekran aynı üretici ve ürün kimliğine sahip. HiDPI kullanmak için diğer ekranların bağlantısını kesin.
            HiDPI’yi etkinleştir
            Esnek ölçeklemeyi etkinleştir
            HiDPI’yi yapılandırmak için ekranı doğrudan bağlayın ve yansıtmayı kapatın.
            Esnek ölçekleme yüklendi
            HiDPI yüklendi
            Bu modelin ayarı başka bir ekran kimliğine ait. Devam etmeden önce önceki ayarı geri yükleyin.
            Değişikliği onaylamazsanız 15 saniye sonra önceki ekran moduna dönülür.
            Değişiklikleri koru
            Geri al
            Ekranı yeniden bağlayın. Liste güncellenmezse Mac’i yeniden başlatın.
            Ayar güncellenemedi. Yönetici onayını ve dosyanın başka bir araçla değiştirilip değiştirilmediğini kontrol edin.
            macOS çözünürlüğü değiştiremedi.
            Mevcut yenileme hızına uyan HiDPI modu yok. Ekranı yeniden bağlayın veya Mac’i yeniden başlatın.
            Esnek ölçekleme
            Çözünürlük
            Yenileme hızı
            """
        case .ru:
            return """
            Масштабирование HiDPI
            Включите HiDPI с разрешения администратора. macOS применяет настройку ко всем мониторам той же модели, включая подключённые позже.
            Подключите внешний монитор для настройки масштаба.
            Монитор отключён
            Восстановить прежнюю настройку
            Vorssaint требуется разрешение администратора для изменения настроек монитора.
            Не удалось восстановить настройки отключённого монитора.
            У нескольких мониторов совпадают ID производителя и модели. Для использования HiDPI отключите остальные мониторы.
            Включить HiDPI
            Включить гибкое масштабирование
            Подключите монитор напрямую и выключите видеоповтор для настройки HiDPI.
            Гибкое масштабирование установлено
            HiDPI установлен
            Для этой модели установлена настройка с другим ID монитора. Сначала восстановите прежнюю настройку.
            Если не сохранить изменение, через 15 секунд вернётся прежний режим.
            Сохранить изменения
            Отменить
            Подключите монитор заново. Если список не обновится, перезагрузите Mac.
            Не удалось изменить настройку. Проверьте разрешение администратора и не изменил ли файл другой инструмент.
            macOS не удалось изменить разрешение.
            Нет режима HiDPI с текущей частотой обновления. Подключите монитор заново или перезагрузите Mac.
            Гибкое масштабирование
            Разрешение
            Частота обновления
            """
        case .es:
            return """
            Escalado HiDPI
            Activa HiDPI con autorización de administrador. macOS aplica la configuración a todas las pantallas del mismo modelo, incluso a las que se conecten después.
            Conecta una pantalla externa para configurar el escalado.
            Pantalla desconectada
            Restaurar configuración anterior
            Vorssaint necesita autorización de administrador para cambiar la configuración de la pantalla.
            No se pudo restaurar la configuración de la pantalla desconectada.
            Varias pantallas tienen el mismo ID de fabricante y producto. Desconecta las demás para usar los modos HiDPI.
            Activar HiDPI
            Activar escalado flexible
            Conecta la pantalla directamente y desactiva la duplicación para configurar HiDPI.
            Escalado flexible instalado
            HiDPI instalado
            Este modelo tiene una configuración instalada con otro identificador de pantalla. Restáurala antes de continuar.
            Si no conservas el cambio, el modo anterior se restaurará en 15 segundos.
            Conservar cambios
            Revertir
            Vuelve a conectar la pantalla. Si la lista no se actualiza, reinicia el Mac.
            No se pudo actualizar la configuración. Comprueba la autorización y si otra herramienta modificó el archivo.
            macOS no pudo cambiar la resolución.
            Ningún modo HiDPI coincide con la frecuencia actual. Vuelve a conectar la pantalla o reinicia el Mac.
            Escalado flexible
            Resolución
            Frecuencia de actualización
            """
        case .sk:
            return """
            Škálovanie HiDPI
            Zapnite HiDPI so súhlasom správcu. macOS použije nastavenie pre všetky displeje rovnakého modelu, aj tie pripojené neskôr.
            Pripojte externý displej a nastavte škálovanie.
            Odpojený displej
            Obnoviť predchádzajúce nastavenie
            Vorssaint potrebuje súhlas správcu na zmenu nastavenia displeja.
            Nastavenie odpojeného displeja sa nepodarilo obnoviť.
            Viaceré displeje majú rovnaký identifikátor výrobcu a produktu. Ak chcete použiť HiDPI, ostatné odpojte.
            Zapnúť HiDPI
            Zapnúť flexibilné škálovanie
            Pripojte displej priamo a vypnite zrkadlenie, aby ste mohli nastaviť HiDPI.
            Flexibilné škálovanie nainštalované
            HiDPI nainštalované
            Pre tento model je nainštalované nastavenie s iným identifikátorom displeja. Najprv ho obnovte.
            Ak zmenu nepotvrdíte, do 15 sekúnd sa obnoví predchádzajúci režim.
            Ponechať zmeny
            Vrátiť späť
            Znovu pripojte displej. Ak sa zoznam neaktualizuje, reštartujte Mac.
            Nastavenie sa nepodarilo zmeniť. Skontrolujte povolenie správcu a či súbor nezmenil iný nástroj.
            macOS nedokázal zmeniť rozlíšenie.
            Žiadny režim HiDPI nezodpovedá aktuálnej obnovovacej frekvencii. Pripojte displej znova alebo reštartujte Mac.
            Flexibilné škálovanie
            Rozlíšenie
            Obnovovacia frekvencia
            """
        case .de:
            return """
            HiDPI-Skalierung
            Aktiviere HiDPI mit Administratorfreigabe. macOS verwendet die Einstellung für alle Displays desselben Modells, auch für später angeschlossene.
            Schließe ein externes Display an, um die Skalierung einzurichten.
            Getrenntes Display
            Vorherige Konfiguration wiederherstellen
            Vorssaint benötigt eine Administratorfreigabe, um die Displaykonfiguration zu ändern.
            Die Konfiguration des getrennten Displays konnte nicht wiederhergestellt werden.
            Mehrere Displays haben dieselbe Hersteller- und Produkt-ID. Trenne die übrigen Displays, um HiDPI zu nutzen.
            HiDPI aktivieren
            Flexible Skalierung aktivieren
            Schließe das Display direkt an und deaktiviere die Bildschirmsynchronisierung, um HiDPI einzurichten.
            Flexible Skalierung installiert
            HiDPI installiert
            Für dieses Modell wurde eine Konfiguration mit einer anderen Display-ID installiert. Stelle zuerst die vorherige Konfiguration wieder her.
            Ohne Bestätigung wird der vorherige Modus nach 15 Sekunden wiederhergestellt.
            Änderungen behalten
            Zurücksetzen
            Schließe das Display erneut an. Starte den Mac neu, falls die Liste nicht aktualisiert wird.
            Die Konfiguration konnte nicht geändert werden. Prüfe die Administratorfreigabe und ob ein anderes Programm die Datei geändert hat.
            macOS konnte die Auflösung nicht ändern.
            Kein HiDPI-Modus passt zur aktuellen Bildwiederholrate. Schließe das Display erneut an oder starte den Mac neu.
            Flexible Skalierung
            Auflösung
            Bildwiederholrate
            """
        case .fr:
            return """
            Mise à l’échelle HiDPI
            Activez HiDPI avec l’autorisation d’un administrateur. macOS applique ce réglage à tous les écrans du même modèle, y compris ceux connectés ultérieurement.
            Connectez un écran externe pour régler la mise à l’échelle.
            Écran déconnecté
            Restaurer la configuration précédente
            Vorssaint a besoin de l’autorisation d’un administrateur pour modifier la configuration de l’écran.
            La configuration de l’écran déconnecté n’a pas pu être restaurée.
            Plusieurs écrans partagent les mêmes identifiants de fabricant et de produit. Déconnectez les autres pour utiliser HiDPI.
            Activer HiDPI
            Activer la mise à l’échelle flexible
            Connectez directement l’écran et désactivez la recopie vidéo pour configurer HiDPI.
            Mise à l’échelle flexible installée
            HiDPI installé
            Une configuration a été installée pour ce modèle avec un autre identifiant d’écran. Restaurez la configuration précédente avant de continuer.
            Le mode précédent sera rétabli après 15 secondes si vous ne conservez pas la modification.
            Conserver les modifications
            Rétablir
            Reconnectez l’écran. Si la liste ne s’actualise pas, redémarrez le Mac.
            La configuration n’a pas pu être modifiée. Vérifiez l’autorisation et si un autre outil a modifié le fichier.
            macOS n’a pas pu changer la résolution.
            Aucun mode HiDPI ne correspond à la fréquence actuelle. Reconnectez l’écran ou redémarrez le Mac.
            Mise à l’échelle flexible
            Résolution
            Fréquence de rafraîchissement
            """
        case .it:
            return """
            Ridimensionamento HiDPI
            Attiva HiDPI con l’autorizzazione di un amministratore. macOS applica l’impostazione a tutti i monitor dello stesso modello, anche a quelli collegati in seguito.
            Collega un monitor esterno per impostare il ridimensionamento.
            Monitor scollegato
            Ripristina configurazione precedente
            Vorssaint richiede l’autorizzazione di un amministratore per modificare la configurazione del monitor.
            Impossibile ripristinare la configurazione del monitor scollegato.
            Più monitor condividono gli ID del produttore e del prodotto. Scollega gli altri per usare HiDPI.
            Attiva HiDPI
            Attiva ridimensionamento flessibile
            Collega direttamente il monitor e disattiva la duplicazione per configurare HiDPI.
            Ridimensionamento flessibile installato
            HiDPI installato
            Per questo modello è installata una configurazione con un altro ID monitor. Ripristina la configurazione precedente prima di procedere.
            Se non confermi la modifica, la modalità precedente verrà ripristinata dopo 15 secondi.
            Mantieni modifiche
            Ripristina
            Ricollega il monitor. Se l’elenco non si aggiorna, riavvia il Mac.
            Impossibile aggiornare la configurazione. Verifica l’autorizzazione e se un altro strumento ha modificato il file.
            macOS non è riuscito a cambiare la risoluzione.
            Nessuna modalità HiDPI corrisponde alla frequenza attuale. Ricollega il monitor o riavvia il Mac.
            Ridimensionamento flessibile
            Risoluzione
            Frequenza di aggiornamento
            """
        case .ja:
            return """
            HiDPI スケーリング
            管理者の承認を得て HiDPI を有効にします。macOS は後から接続したものを含め、同じモデルのすべてのディスプレイに設定を適用します。
            スケーリングを設定するには外部ディスプレイを接続してください。
            未接続のディスプレイ
            以前の設定を復元
            ディスプレイ設定を変更するには Vorssaint に管理者の承認が必要です。
            未接続のディスプレイの設定を復元できませんでした。
            複数のディスプレイで製造元と製品の ID が一致しています。HiDPI を使うには他のディスプレイを取り外してください。
            HiDPI を有効にする
            柔軟なスケーリングを有効にする
            HiDPI を設定するにはディスプレイを直接接続し、ミラーリングを解除してください。
            柔軟なスケーリングをインストール済み
            HiDPI をインストール済み
            このモデルは別のディスプレイ ID で設定されています。続行するには以前の設定を復元してください。
            変更を確定しない場合は、15秒後に前のモードに戻ります。
            変更を保持
            元に戻す
            ディスプレイを接続し直してください。リストが更新されない場合は Mac を再起動してください。
            設定を更新できませんでした。管理者の承認と、他のツールがファイルを変更していないか確認してください。
            macOS は解像度を変更できませんでした。
            現在のリフレッシュレートに合う HiDPI モードがありません。ディスプレイを接続し直すか Mac を再起動してください。
            柔軟なスケーリング
            解像度
            リフレッシュレート
            """
        case .uk:
            return """
            Масштабування HiDPI
            Увімкніть HiDPI з дозволу адміністратора. macOS застосує налаштування до всіх моніторів цієї моделі, зокрема підключених пізніше.
            Під’єднайте зовнішній монітор, щоб налаштувати масштаб.
            Від’єднаний монітор
            Відновити попереднє налаштування
            Vorssaint потрібен дозвіл адміністратора, щоб змінити налаштування монітора.
            Не вдалося відновити налаштування від’єднаного монітора.
            Кілька моніторів мають однакові ID виробника та продукту. Від’єднайте решту, щоб скористатися HiDPI.
            Увімкнути HiDPI
            Увімкнути гнучке масштабування
            Під’єднайте монітор напряму та вимкніть дублювання екрана, щоб налаштувати HiDPI.
            Гнучке масштабування встановлено
            HiDPI встановлено
            Для цієї моделі встановлено налаштування з іншим ID монітора. Спершу відновіть попереднє налаштування.
            Якщо не зберегти зміну, попередній режим буде відновлено через 15 секунд.
            Зберегти зміни
            Скасувати
            Під’єднайте монітор знову. Якщо список не оновиться, перезапустіть Mac.
            Не вдалося змінити налаштування. Перевірте дозвіл адміністратора й чи не змінив файл інший засіб.
            macOS не вдалося змінити роздільність.
            Немає режиму HiDPI з поточною частотою оновлення. Під’єднайте монітор знову або перезапустіть Mac.
            Гнучке масштабування
            Роздільність
            Частота оновлення
            """
        case .zhHans:
            return """
            HiDPI 缩放
            经管理员批准后启用 HiDPI。macOS 会将此设置应用于所有同型号显示器，包括之后连接的显示器。
            请连接外接显示器以配置缩放。
            已断开的显示器
            恢复先前的配置
            Vorssaint 需要管理员批准才能修改显示器配置。
            无法恢复已断开显示器的配置。
            多台显示器的厂商和产品 ID 相同。请断开其余显示器后使用 HiDPI。
            启用 HiDPI
            启用灵活缩放
            请直接连接显示器并关闭镜像，以配置 HiDPI。
            已安装灵活缩放
            已安装 HiDPI
            此型号已使用另一个显示器 ID 安装配置。请先恢复先前的配置。
            如果不保留更改，15 秒后将恢复之前的显示模式。
            保留更改
            还原
            请重新连接显示器。如果列表未更新，请重新启动 Mac。
            无法更新配置。请检查管理员授权，以及文件是否被其他工具修改。
            macOS 无法切换分辨率。
            没有与当前刷新率匹配的 HiDPI 模式。请重新连接显示器或重新启动 Mac。
            灵活缩放
            分辨率
            刷新率
            """
        case .zhTW:
            return """
            HiDPI 縮放
            經管理者核准後啟用 HiDPI。macOS 會將此設定套用至所有同型號顯示器，包括稍後連接的顯示器。
            請連接外接顯示器以設定縮放。
            已中斷連線的顯示器
            回復先前的設定
            Vorssaint 需要管理者核准才能修改顯示器設定。
            無法回復已中斷連線顯示器的設定。
            多部顯示器的廠商與產品 ID 相同。請中斷其他顯示器的連線後使用 HiDPI。
            啟用 HiDPI
            啟用彈性縮放
            請直接連接顯示器並關閉鏡像輸出，以設定 HiDPI。
            已安裝彈性縮放
            已安裝 HiDPI
            此型號已使用另一個顯示器 ID 安裝設定。請先回復先前的設定。
            若未保留變更，15 秒後將恢復先前的顯示模式。
            保留變更
            還原
            請重新連接顯示器。如果列表未更新，請重新啟動 Mac。
            無法更新設定。請檢查管理者授權，以及檔案是否遭其他工具修改。
            macOS 無法切換解析度。
            沒有符合目前更新頻率的 HiDPI 模式。請重新連接顯示器或重新啟動 Mac。
            彈性縮放
            解析度
            更新頻率
            """
        case .zhHK:
            return """
            HiDPI 縮放
            經管理員批准後啟用 HiDPI。macOS 會將此設定套用至所有同型號顯示器，包括稍後連接的顯示器。
            請連接外置顯示器以設定縮放。
            已中斷連接的顯示器
            還原先前的設定
            Vorssaint 需要管理員批准才能修改顯示器設定。
            無法還原已中斷連接顯示器的設定。
            多部顯示器的廠商與產品 ID 相同。請中斷其他顯示器的連接後使用 HiDPI。
            啟用 HiDPI
            啟用靈活縮放
            請直接連接顯示器並關閉鏡像，以設定 HiDPI。
            已安裝靈活縮放
            已安裝 HiDPI
            此型號已使用另一個顯示器 ID 安裝設定。請先還原先前的設定。
            若不保留變更，15 秒後會回復先前的顯示模式。
            保留變更
            回復
            請重新連接顯示器。如列表未更新，請重新啟動 Mac。
            無法更新設定。請檢查管理員授權，以及檔案是否被其他工具修改。
            macOS 無法切換解像度。
            沒有符合目前更新率的 HiDPI 模式。請重新連接顯示器或重新啟動 Mac。
            靈活縮放
            解像度
            更新率
            """
        }
    }
}
