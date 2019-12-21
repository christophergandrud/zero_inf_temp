RDIR = .

RSOURCE = $(wildcard $(RDIR)/*.R)

OUT_FILES = $(RSOURCE:.R=.Rout)

all: $(OUT_FILES)

$(RDIR)/%.Rout: $(RDIR)/%.R
		R CMD BATCH $<

clean:
	rm -fv $(OUT_FILES)
