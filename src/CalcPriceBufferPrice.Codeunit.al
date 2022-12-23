codeunit 50200 "Calc. Price Buffer - Price" implements "Line With Price"
{
    var
        CalcPriceBuffer: Record "Calc. Price Buffer";
        PriceSourceList: codeunit "Price Source List";
        CurrPriceType: Enum "Price Type";
        PriceCalculated: Boolean;

    procedure GetTableNo(): Integer
    begin
        exit(Database::"Sales Line")
    end;

    procedure SetLine(PriceType: Enum "Price Type"; Line: Variant)
    begin
        CalcPriceBuffer := Line;
        CurrPriceType := PriceType;
        PriceCalculated := false;
        AddSources();
    end;

    procedure SetSources(var NewPriceSourceList: codeunit "Price Source List")
    begin
        PriceSourceList.Copy(NewPriceSourceList);
    end;

    procedure GetLine(var Line: Variant)
    begin
        Line := CalcPriceBuffer;
    end;

    procedure GetPriceType(): Enum "Price Type"
    begin
        exit(CurrPriceType);
    end;

    procedure Verify()
    begin
        CalcPriceBuffer.TestField("Qty. per Unit of Measure");
        if CalcPriceBuffer."Currency Code" <> '' then
            CalcPriceBuffer.TestField("Currency Factor");
    end;

    procedure SetAssetSourceForSetup(var DtldPriceCalculationSetup: Record "Dtld. Price Calculation Setup"): Boolean
    begin
        DtldPriceCalculationSetup.Init();
        DtldPriceCalculationSetup.Type := CurrPriceType;
        DtldPriceCalculationSetup.Method := CalcPriceBuffer."Price Calculation Method";
        DtldPriceCalculationSetup."Asset Type" := CalcPriceBuffer."Price Asset Type";
        DtldPriceCalculationSetup."Asset No." := CalcPriceBuffer."No.";
        exit(PriceSourceList.GetSourceGroup(DtldPriceCalculationSetup));
    end;

    local procedure SetAssetSource(var PriceCalculationBuffer: Record "Price Calculation Buffer"): Boolean
    begin
        PriceCalculationBuffer."Price Type" := CurrPriceType;
        PriceCalculationBuffer."Asset Type" := CalcPriceBuffer."Price Asset Type";
        PriceCalculationBuffer."Asset No." := CalcPriceBuffer."No.";
        exit((PriceCalculationBuffer."Asset Type" <> PriceCalculationBuffer."Asset Type"::" ") and (PriceCalculationBuffer."Asset No." <> ''));
    end;

    procedure CopyToBuffer(var PriceCalculationBufferMgt: Codeunit "Price Calculation Buffer Mgt."): Boolean
    var
        PriceCalculationBuffer: Record "Price Calculation Buffer";
    begin
        PriceCalculationBuffer.Init();
        if not SetAssetSource(PriceCalculationBuffer) then
            exit(false);

        FillBuffer(PriceCalculationBuffer);
        PriceCalculationBufferMgt.Set(PriceCalculationBuffer, PriceSourceList);
        exit(true);
    end;

    local procedure FillBuffer(var PriceCalculationBuffer: Record "Price Calculation Buffer")
    var
        Item: Record Item;
        Resource: Record Resource;
    begin
        PriceCalculationBuffer."Price Calculation Method" := CalcPriceBuffer."Price Calculation Method";

        case PriceCalculationBuffer."Asset Type" of
            PriceCalculationBuffer."Asset Type"::Item:
                begin
                    PriceCalculationBuffer."Variant Code" := CalcPriceBuffer."Variant Code";
                    Item.Get(PriceCalculationBuffer."Asset No.");
                    PriceCalculationBuffer."Unit Price" := Item."Unit Price";
                    PriceCalculationBuffer."Item Disc. Group" := Item."Item Disc. Group";
                    if PriceCalculationBuffer."VAT Prod. Posting Group" = '' then
                        PriceCalculationBuffer."VAT Prod. Posting Group" := Item."VAT Prod. Posting Group";
                end;
            PriceCalculationBuffer."Asset Type"::Resource:
                begin
                    PriceCalculationBuffer."Work Type Code" := CalcPriceBuffer."Work Type Code";
                    Resource.Get(PriceCalculationBuffer."Asset No.");
                    PriceCalculationBuffer."Unit Price" := Resource."Unit Price";
                    if PriceCalculationBuffer."VAT Prod. Posting Group" = '' then
                        PriceCalculationBuffer."VAT Prod. Posting Group" := Resource."VAT Prod. Posting Group";
                end;
        end;
        PriceCalculationBuffer."Location Code" := CalcPriceBuffer."Location Code";
        PriceCalculationBuffer."Document Date" := CalcPriceBuffer."Calculation Date";

        // Currency
        PriceCalculationBuffer.Validate("Currency Code", CalcPriceBuffer."Currency Code");
        PriceCalculationBuffer."Currency Factor" := CalcPriceBuffer."Currency Factor";

        // UoM
        PriceCalculationBuffer.Quantity := Abs(CalcPriceBuffer.Quantity);
        PriceCalculationBuffer."Unit of Measure Code" := CalcPriceBuffer."Unit of Measure Code";
        PriceCalculationBuffer."Qty. per Unit of Measure" := CalcPriceBuffer."Qty. per Unit of Measure";
        // Discounts
        PriceCalculationBuffer."Line Discount %" := CalcPriceBuffer."Line Discount %";
        PriceCalculationBuffer."Allow Line Disc." := IsDiscountAllowed();
    end;

    local procedure AddSources()
    begin
        PriceSourceList.Init();
        case CurrPriceType of
            CurrPriceType::Sale:
                AddCustomerSources();
            CurrPriceType::Purchase:
                AddVendorSources();
        end;
    end;

    local procedure AddCustomerSources()
    begin
        PriceSourceList.Add("Price Source Type"::"All Customers");
        PriceSourceList.Add("Price Source Type"::Customer, CalcPriceBuffer.CustomerVendorNo);
        PriceSourceList.Add("Price Source Type"::Contact, CalcPriceBuffer."Contact No.");
        AddActivatedCampaignsAsSource();
        PriceSourceList.Add("Price Source Type"::"Customer Price Group", CalcPriceBuffer."Customer Price Group");
        PriceSourceList.Add("Price Source Type"::"Customer Disc. Group", CalcPriceBuffer."Customer Disc. Group");
    end;

    local procedure AddVendorSources()
    begin
        PriceSourceList.Add("Price Source Type"::"All Vendors");
        PriceSourceList.Add("Price Source Type"::Vendor, CalcPriceBuffer.CustomerVendorNo);
        PriceSourceList.Add("Price Source Type"::Contact, CalcPriceBuffer."Contact No.");
    end;

    procedure SetPrice(AmountType: Enum "Price Amount Type"; PriceListLine: Record "Price List Line")
    begin
        case AmountType of
            AmountType::Price:
                case CurrPriceType of
                    CurrPriceType::Sale:
                        begin
                            CalcPriceBuffer."Unit Price" := PriceListLine."Unit Price";
                            PriceCalculated := true;
                        end;
                    CurrPriceType::Purchase:
                        CalcPriceBuffer."Unit Price" := PriceListLine."Direct Unit Cost";
                end;
            AmountType::Discount:
                CalcPriceBuffer."Line Discount %" := PriceListLine."Line Discount %";
        end;
    end;

    procedure ValidatePrice(AmountType: enum "Price Amount Type")
    begin
        case AmountType of
            AmountType::Discount:
                begin
                    CalcPriceBuffer.Validate("Line Discount %");
                end;
            AmountType::Price:
                case CurrPriceType of
                    CurrPriceType::Sale:
                        CalcPriceBuffer.Validate("Unit Price");
                    CurrPriceType::Purchase:
                        CalcPriceBuffer.Validate("Unit Price");
                end;
        end;
    end;

    procedure AddActivatedCampaignsAsSource()
    var
        TempTargetCampaignGr: Record "Campaign Target Group" temporary;
        SourceType: Enum "Price Source Type";
    begin
        if FindActivatedCampaign(TempTargetCampaignGr) then
            repeat
                PriceSourceList.Add(SourceType::Campaign, TempTargetCampaignGr."Campaign No.");
            until TempTargetCampaignGr.Next() = 0;
    end;

    local procedure FindActivatedCampaign(var TempCampaignTargetGr: Record "Campaign Target Group" temporary): Boolean
    var
        PriceSourceType: enum "Price Source Type";
    begin
        TempCampaignTargetGr.Reset();
        TempCampaignTargetGr.DeleteAll();

        if PriceSourceList.GetValue(PriceSourceType::Campaign) = '' then
            if not FindCustomerCampaigns(PriceSourceList.GetValue(PriceSourceType::Customer), TempCampaignTargetGr) then
                FindContactCompanyCampaigns(PriceSourceList.GetValue(PriceSourceType::Contact), TempCampaignTargetGr);

        exit(TempCampaignTargetGr.FindFirst());
    end;

    local procedure FindCustomerCampaigns(CustomerNo: Code[20]; var TempCampaignTargetGr: Record "Campaign Target Group" temporary) Found: Boolean;
    var
        CampaignTargetGr: Record "Campaign Target Group";
    begin
        CampaignTargetGr.SetRange(Type, CampaignTargetGr.Type::Customer);
        CampaignTargetGr.SetRange("No.", CustomerNo);
        Found := CampaignTargetGr.CopyTo(TempCampaignTargetGr);
    end;

    local procedure FindContactCompanyCampaigns(ContactNo: Code[20]; var TempCampaignTargetGr: Record "Campaign Target Group" temporary) Found: Boolean
    var
        CampaignTargetGr: Record "Campaign Target Group";
        Contact: Record Contact;
    begin
        if Contact.Get(ContactNo) then begin
            CampaignTargetGr.SetRange(Type, CampaignTargetGr.Type::Contact);
            CampaignTargetGr.SetRange("No.", Contact."Company No.");
            Found := CampaignTargetGr.CopyTo(TempCampaignTargetGr);
        end;
    end;

    procedure SetLine(PriceType: enum "Price Type"; Header: Variant; Line: Variant);
    begin
        SetLine(PriceType, Line);
    end;

    procedure GetLine(var Header: Variant; var Line: Variant);
    begin
        GetLine(Line);
    end;

    procedure GetAssetType(): enum "Price Asset Type";
    begin
        exit(CalcPriceBuffer."Price Asset Type");
    end;

    procedure IsPriceUpdateNeeded(AmountType: enum "Price Amount Type"; FoundPrice: Boolean; CalledByFieldNo: Integer): Boolean;
    begin
        exit(true);
    end;

    procedure IsDiscountAllowed(): Boolean;
    begin
        exit(true);
    end;

    procedure Update(AmountType: enum "Price Amount Type");
    begin

    end;
}
