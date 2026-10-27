(defun C:H2A (/ _set_prefs _apply_mask _draw_leader _bring_to_top _inside_p _auto_color m_factor suffix mask t_size go ent obj id ins_pt field_str mtext_obj ename elist ss i expr measure_val current_lts cel_val)
  (vl-load-com)
  
  ;; 1. 根據 MEASUREMENT 自動嘗試載入對應的 HIDDEN 線型
  (if (null (tblsearch "LTYPE" "HIDDEN"))
    (if (= (getvar "MEASUREMENT") 1)
      (vl-catch-all-apply 'vla-load (list (vla-get-Linetypes (vla-get-ActiveDocument (vlax-get-acad-object))) "HIDDEN" "acadiso.lin"))
      (vl-catch-all-apply 'vla-load (list (vla-get-Linetypes (vla-get-ActiveDocument (vlax-get-acad-object))) "HIDDEN" "acad.lin"))
    )
  )
  
  ;; ==================================================
  ;; 環境初始化設定 (正確反比公式：CEL = 定值 / LTS)
  ;; ==================================================
  (setvar "CMDECHO" 0)
  
  ;; A. 自動新增/設定 "AREA" 圖層：顏色 10, 線型 HIDDEN, 線粗 0.3mm
  (vl-catch-all-apply '(lambda () 
    (command "-LAYER" "M" "AREA" "C" "10" "" "L" "HIDDEN" "" "LW" "0.3" "" "")
  ))
  
  ;; B. 移除舊有的強制設定線粗與字高，改由後續動態控制或預設
  
  ;; D. 動態讀取當前環境變數，依反比公式計算 CELTSCALE
  (setq measure_val (getvar "MEASUREMENT"))
  (setq current_lts (getvar "LTSCALE"))
  
  ;; 防止 LTSCALE 為 0 導致除以零的錯誤（安全機制）
  (if (<= current_lts 0) (setq current_lts 1.0))

  (if (= measure_val 1)
    (setq cel_val (/ 250.0 current_lts))         ;; 公制環境：定值 250 (當 LTS=1000, CEL=0.25; 當 LTS=1, CEL=250)
    (setq cel_val (/ 250.0 current_lts))        ;; 英制環境：定值 250 * 25.4 = 6350
  )
  
  (vl-catch-all-apply 'setvar (list "CELTSCALE" cel_val))
  (princ (strcat "\n[系統提示] 已偵測當前 LTS=" (rtos current_lts 2 2) "，依反比公式自動將 CELTSCALE 設定為: " (rtos cel_val 2 5)))
  
  (setvar "CMDECHO" 1)

  ;; --- 內部函數：設定 ---
  (defun _set_prefs ()
    (setq m_factor (getreal "\n輸入面積乘數 (如 mm2 轉 m2 請輸入 0.000001) <1.0>: "))
    (if (null m_factor) (setq m_factor 1.0))
    
    (setq suffix (getstring T "\n輸入面積字尾 <M²>: "))
    (if (= suffix "") (setq suffix "M²"))
    
    (setq t_size (getreal "\n輸入面積文字字高 <1800.0>: "))
    (if (null t_size) (setq t_size 1800.0))
    
    (initget "Yes No")
    (setq mask (getkword "\n是否開啟文字背景遮罩？ [是(Y) / 否(N)] <Y>: "))
    (if (or (null mask) (= mask "Yes")) (setq mask "Y") (setq mask "N"))
    
    (vlax-ldata-put "AreaPrefs" "Factor" m_factor)
    (vlax-ldata-put "AreaPrefs" "Suffix" suffix)
    (vlax-ldata-put "AreaPrefs" "TextSize" t_size)
    (vlax-ldata-put "AreaPrefs" "Mask" mask)
  )

  ;; --- 內部函數：強制 1.0 遮罩 (DXF 暴力法) ---
  (defun _apply_mask (obj_mtext)
    (setq ename (vlax-vla-object->ename obj_mtext))
    (setq elist (entget ename))
    (if (= (vlax-ldata-get "AreaPrefs" "Mask") "Y")
      (setq elist (append elist (list '(90 . 3) '(63 . 256) '(45 . 1.0) '(441 . 0))))
      (setq elist (append elist '((90 . 0))))
    )
    (entmod elist)
    (entupd ename)
  )

  ;; --- 內部函數：純幾何點在多邊形內部的判斷 (Ray-Casting 演算法) ---
  (defun _inside_p (pt p_list / cn p1 p2)
    (setq cn 0)
    (while (> (length p_list) 1)
      (setq p1 (car p_list) p2 (cadr p_list) p_list (cdr p_list))
      (if (or (and (<= (cadr p1) (cadr pt)) (> (cadr p2) (cadr pt)))
              (and (> (cadr p1) (cadr pt)) (<= (cadr p2) (cadr pt))))
        (if (< (car pt) (+ (car p1) (* (/ (- (cadr pt) (cadr p1)) (- (cadr p2) (cadr p1))) (- (car p2) (car p1)))))
          (setq cn (1+ cn))
        )
      )
    )
    (= (rem cn 2) 1)
  )

  ;; --- 內部函數：精準判定內外並繪製連接線 ---
  (defun _draw_leader (hatch_obj mtext_obj cel_scale / min_pt max_pt cen_pt txt_min txt_max txt_cen close_pt min_dist dist vec len offset_pt lw_obj array_pts pts_list inside)
    (vla-GetBoundingBox hatch_obj 'min_pt 'max_pt)
    (setq min_pt (vlax-safearray->list min_pt) max_pt (vlax-safearray->list max_pt)
          cen_pt (list (/ (+ (car min_pt) (car max_pt)) 2.0) (/ (+ (cadr min_pt) (cadr max_pt)) 2.0) 0.0))
    
    (vla-GetBoundingBox mtext_obj 'txt_min 'txt_max)
    (setq txt_min (vlax-safearray->list txt_min) txt_max (vlax-safearray->list txt_max)
          txt_cen (list (/ (+ (car txt_min) (car txt_max)) 2.0) (/ (+ (cadr txt_min) (cadr txt_max)) 2.0) 0.0))
    
    (setq elist (entget (vlax-vla-object->ename hatch_obj)))
    (setq pts_list (mapcar 'cdr (vl-remove-if-not '(lambda (x) (= (car x) 10)) elist)))
    
    (if (and pts_list (not (equal (car pts_list) (last pts_list))))
      (setq pts_list (append pts_list (list (car pts_list))))
    )
    
    (setq inside nil)
    (if pts_list (setq inside (_inside_p txt_cen pts_list)))
    
    (if (not inside)
      (progn
        (setq min_dist nil close_pt nil)
        (foreach pt pts_list
          (setq pt (list (car pt) (cadr pt) 0.0))
          (setq dist (distance txt_cen pt))
          (if (or (null min_dist) (< dist min_dist)) (setq min_dist dist close_pt pt))
        )
        (if (null close_pt) (setq close_pt (list (car min_pt) (cadr min_pt) 0.0)))
        
        (setq vec (mapcar '- cen_pt close_pt) len (distance cen_pt close_pt))
        (if (> len 2000.0) 
          (setq offset_pt (mapcar '(lambda (c v) (+ c (* (/ 2000.0 len) v))) close_pt vec))
          (setq offset_pt close_pt)
        )
        
        (setq array_pts (vlax-make-safearray vlax-vbDouble '(0 . 3)))
        (vlax-safearray-fill array_pts (list (car offset_pt) (cadr offset_pt) (car txt_cen) (cadr txt_cen)))
        
        (setq lw_obj (vla-AddLightweightPolyline (vla-get-modelspace (vla-get-activedocument (vlax-get-acad-object))) array_pts))
        (vla-put-Linetype lw_obj "HIDDEN")
        (vla-put-LinetypeScale lw_obj cel_scale)
        (vla-put-ConstantWidth lw_obj 0.0)
      )
      (princ "\n[提示] 文字位於填充線上方，自動省略連線段。")
    )
  )

  ;; --- 內部函數：將指定物件移至最上層 ---
  (defun _bring_to_top (obj_mtext / doc dictionary extensionDictionary sortEntsObj obj_array)
    (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
    (setq extensionDictionary (vla-GetExtensionDictionary (vla-get-ModelSpace doc)))
    (setq sortEntsObj (vlax-invoke extensionDictionary 'AddObject "ACAD_SORTENTS" "AcDbSortentsTable"))
    (setq obj_array (vlax-make-safearray vlax-vbObject '(0 . 0)))
    (vlax-safearray-put-element obj_array 0 obj_mtext)
    (vla-MoveToTop sortEntsObj obj_array)
  )

  ;; --- 【輪盤滾動防撞版】自動相鄰分色與透明度處理 ---
  (defun _auto_color (ss / color_list i ent_name h_obj h_list adj_matrix box_list b1 b2 overlaps neighbors_colors chosen_color old_cmdecho pair found start_color_idx loop_idx cl check_idx)
    (setq color_list '(30 50 80 140 190 220))
    
    (setq i 0 h_list nil box_list nil)
    (repeat (sslength ss)
      (setq ent_name (ssname ss i))
      (setq h_obj (vlax-ename->vla-object ent_name))
      (setq h_list (cons (list i ent_name h_obj) h_list))
      
      (vla-GetBoundingBox h_obj 'min_pt 'max_pt)
      (setq box_list (cons (list (vlax-safearray->list min_pt) (vlax-safearray->list max_pt)) box_list))
      (setq i (1+ i))
    )
    (setq h_list (reverse h_list) box_list (reverse box_list))
    
    (setq adj_matrix (mapcar '(lambda (x) (mapcar '(lambda (y) 0) h_list)) h_list))
    (setq i 0)
    (while (< i (length h_list))
      (setq j (1+ i))
      (while (< j (length h_list))
        (setq b1 (nth i box_list) b2 (nth j box_list))
        (setq overlaps (and (<= (caar b1) (+ (caadr b2) 2.0)) (>= (caadr b1) (- (caar b2) 2.0))
                            (<= (cadar b1) (+ (cadadr b2) 2.0)) (>= (cadadr b1) (- (cadar b2) 2.0))))
        (if overlaps
          (progn
            (setq adj_matrix (subst (subst 1 (nth j (nth i adj_matrix)) (nth i adj_matrix)) (nth i adj_matrix) adj_matrix))
            (setq adj_matrix (subst (subst 1 (nth i (nth j adj_matrix)) (nth j adj_matrix)) (nth j adj_matrix) adj_matrix))
          )
        )
        (setq j (1+ j))
      )
      (setq i (1+ i))
    )
    
    (setq assigned_color (mapcar '(lambda (x) nil) h_list))
    (setq old_cmdecho (getvar "CMDECHO"))
    (setvar "CMDECHO" 0)
    
    (setq start_color_idx 0)
    
    (foreach curr h_list
      (setq curr_idx (car curr)
            ent_name (cadr curr)
            h_obj    (caddr curr))
      
      (setq neighbors_colors nil)
      (setq j 0)
      (while (< j (length h_list))
        (if (= (nth j (nth curr_idx adj_matrix)) 1)
          (if (nth j assigned_color)
            (setq neighbors_colors (cons (nth j assigned_color) neighbors_colors))
          )
        )
        (setq j (1+ j))
      )
      
      (setq chosen_color nil found nil loop_idx 0)
      (while (and (not found) (< loop_idx 6))
        (setq check_idx (rem (+ start_color_idx loop_idx) 6))
        (setq cl (nth check_idx color_list))
        (if (not (member cl neighbors_colors))
          (setq chosen_color cl
                start_color_idx (rem (1+ check_idx) 6)
                found T)
        )
        (setq loop_idx (1+ loop_idx))
      )
      
      (if (null chosen_color) (setq chosen_color (car color_list)))
      (setq assigned_color (subst chosen_color (nth curr_idx assigned_color) assigned_color))
      
      (vl-catch-all-apply '(lambda ()
        (command "_.CHPROP" ent_name "" "_C" (itoa chosen_color) "")
        (command "_.CHPROP" ent_name "" "_TR" "50" "")
      ))
    )
    
    (setvar "CMDECHO" old_cmdecho)
    (vl-cmdf "_.REGEN")
    (princ (strcat "\n[成功] 已完成 " (itoa (length h_list)) " 個填充線的相鄰分色，並套用 50% 透明度。"))
  )

  ;; 2. 初始化：檢查是否有舊設定，若無則套用預設值並儲存
  (if (or (null (vlax-ldata-get "AreaPrefs" "Factor")) 
          (null (vlax-ldata-get "AreaPrefs" "Suffix"))
          (null (vlax-ldata-get "AreaPrefs" "TextSize")))
    (progn
      (vlax-ldata-put "AreaPrefs" "Factor" 1.0)
      (vlax-ldata-put "AreaPrefs" "Suffix" "M²")
      (vlax-ldata-put "AreaPrefs" "TextSize" 1800.0)
      (vlax-ldata-put "AreaPrefs" "Mask" "Y")
    )
  )

  ;; 3. 主迴圈
  (setq go T)
  (while go
    (setq m_factor (vlax-ldata-get "AreaPrefs" "Factor")
          suffix (vlax-ldata-get "AreaPrefs" "Suffix")
          t_size (vlax-ldata-get "AreaPrefs" "TextSize"))
    
    ;; 每次產出文字前，將系統環境的 TEXTSIZE 同步為設定值
    (vl-catch-all-apply 'setvar (list "TEXTSIZE" t_size))
    
    (initget "Settings Multiple Coloring")
    (setq ent (entsel (strcat "\n選取填充線 [多選加總(M) / 自動分色(C) / 設定(S)] (目前字尾:" suffix "): ")))
    
    (cond
      ((= ent "Settings") (_set_prefs))

      ((= ent "Coloring")
       (princ "\n請框選要進行相鄰自動分色的填充線區域...")
       (if (setq ss (ssget '((0 . "HATCH"))))
         (progn
           (_auto_color ss)
           (setq go nil)
         )
         (princ "\n未選取任何填充線。")
       )
      )

      ((= ent "Multiple")
       (princ "\n請選取要加總的填充線...")
       (if (setq ss (ssget '((0 . "HATCH"))))
         (progn
           (setq expr "" i 0)
           (repeat (sslength ss)
             (setq id (vla-get-ObjectID (vlax-ename->vla-object (ssname ss i))))
             (setq expr (strcat expr "%<\\AcObjProp Object(%<\\_ObjId " (itoa id) ">%).Area>% + ") i (1+ i))
           )
           (setq expr (substr expr 1 (- (strlen expr) 3)))
           (setq field_str (strcat "{\\fMicrosoft JhengHei|b0|i0|c136|p34;%<\\AcExpr (" expr ") \\f \"%lu2%pr2%ct8[" (rtos m_factor 2 8) "]%ps[," suffix "]\">% \n}"))
           (if (setq ins_pt (getpoint "\n指定加總面積放置點: "))
             (progn (setq mtext_obj (vla-addMText (vla-get-modelspace (vla-get-activedocument (vlax-get-acad-object))) (vlax-3d-point ins_pt) 0.0 field_str))
                    (_apply_mask mtext_obj)
                    (_bring_to_top mtext_obj)
             ))
         )
       )
      )

      ((and ent (listp ent))
       (setq obj (vlax-ename->vla-object (car ent)))
       (if (= (vla-get-ObjectName obj) "AcDbHatch")
         (progn
           (setq id (vla-get-ObjectID obj))
           (setq field_str (strcat "{\\fMicrosoft JhengHei|b0|i0|c136|p34;%<\\AcObjProp Object(%<\\_ObjId " (itoa id) ">%).Area \\f \"%lu2%pr2%ct8[" (rtos m_factor 2 8) "]%ps[," suffix "]\">% \n}"))
           
           (if (setq ins_pt (getpoint "\n指定面積文字放置點: "))
             (progn 
               (setq mtext_obj (vla-addMText (vla-get-modelspace (vla-get-activedocument (vlax-get-acad-object))) (vlax-3d-point ins_pt) 0.0 field_str))
               (vla-put-AttachmentPoint mtext_obj 5)
               (vla-put-InsertionPoint mtext_obj (vlax-3d-point ins_pt))
               
               (_apply_mask mtext_obj)
               (_draw_leader obj mtext_obj cel_val)
               (_bring_to_top mtext_obj)
             ))
         )
         (princ "\n選取的不是填充線。")
       )
     )
      
      (t (setq go nil))
    )
  )

  (princ "\n指令結束。")
  (princ)
)